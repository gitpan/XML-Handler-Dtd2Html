package XML::Handler::Dtd2Html::Document;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
			xml_decl                => undef,
			dtd                     => undef,
			root_name               => undef,
			list_decl               => [],
			hash_notation           => {},
			hash_entity             => {},
			hash_element            => {},
			hash_attr               => {}
	};
	bless($self, $class);
	return $self;
}

###############################################################################

package XML::Handler::Dtd2Html;

use strict;

use vars qw($VERSION);

$VERSION="0.30";

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
			doc         => new XML::Handler::Dtd2Html::Document(),
			comments    => []
	};
	bless($self, $class);
	return $self;
}

# Content Events (Basic)

sub end_document {
	my $self = shift;
	return $self->{doc};
}

# Declarations Events

sub element_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "element";
	$decl->{used_by} = {};
	$decl->{uses} = {};
	my $name = $decl->{Name};
	$self->{doc}->{hash_element}->{$name} = $decl;
	push @{$self->{doc}->{list_decl}}, $decl;
}

sub attribute_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	my $elt_name = $decl->{eName};
	$self->{doc}->{hash_attr}->{$elt_name} = []
			unless (exists $self->{doc}->{hash_attr}->{$elt_name});
	push @{$self->{doc}->{hash_attr}->{$elt_name}}, $decl;
}

sub internal_entity_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "internal_entity";
	my $name = $decl->{Name};
	unless ($name =~ /^%/) {
		$self->{doc}->{hash_entity}->{$name} = $decl;
		push @{$self->{doc}->{list_decl}}, $decl;
	}
}

sub external_entity_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "external_entity";
	my $name = $decl->{Name};
	unless ($name =~ /^%/) {
		$self->{doc}->{hash_entity}->{$name} = $decl;
		push @{$self->{doc}->{list_decl}}, $decl;
	}
}

# DTD Events

sub notation_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "notation";
	my $name = $decl->{Name};
	$self->{doc}->{hash_notation}->{$name} = $decl;
	push @{$self->{doc}->{list_decl}}, $decl;
}

sub unparsed_entity_decl {
	my $self = shift;
	my ($decl) = @_;
	$self->{comments} = [];
	warn "unparsed entity $decl->{Name}.\n";
}

# Lexical Events

sub start_dtd {
	my $self = shift;
	my ($dtd) = @_;
	if (scalar @{$self->{comments}}) {
		$dtd->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$dtd->{type} = "doctype";
	$self->{doc}->{dtd} = $dtd;
	$self->{doc}->{root_name} = $dtd->{Name};
}

sub comment {
	my $self = shift;
	my ($comment) = @_;
	push @{$self->{comments}}, $comment;
}

# SAX1 Events

sub xml_decl {
	my $self = shift;
	my ($decl) = @_;
	$self->{doc}->{xml_decl} = $decl;
}

###############################################################################

package XML::Handler::Dtd2Html::Document;

use HTML::Template;

sub _process_args {
	my $self = shift;
	my %hash = @_;

	$self->{outfile} = $hash{outfile};

	if (defined $hash{title}) {
		$self->{title} = $hash{title};
	} else {
		$self->{title} =  "DTD " . $self->{root_name};
	}

	$self->{css} = $hash{css};
	$self->{examples} = $hash{examples};
	$self->{filebase} = $hash{outfile};
	$self->{filebase} =~ s/^([^\/]+\/)+//;
	$self->{flag_comment} = $hash{flag_comment};
	$self->{flag_href} = $hash{flag_href};

	$self->{now} = localtime();
	$self->{generator} = "dtd2html " . $XML::Handler::Dtd2Html::VERSION . " (Perl " . $] . ")";

	if (defined $hash{path_tmpl}) {
		$self->{path_tmpl} = [ $hash{path_tmpl} ];
	} else {
		my $language = $hash{language} || 'en';
		my $path = $INC{'XML/Handler/Dtd2Html.pm'};
		$path =~ s/\.pm$//i;
		$self->{path_tmpl} = [ $path . '/' . $language, $path ];
	}

	$self->_cross_ref($hash{flag_zombi});

	if ($hash{flag_multi}) {
		foreach my $decl (@{$self->{list_decl}}) {
			my $type = $decl->{type};
			my $name = $decl->{Name};
			if (exists $decl->{comments}) {
				$decl->{comments} = [ ${$decl->{comments}}[-1] ];
			}
			if ($type eq "element" and exists $self->{hash_attr}->{$name}) {
				foreach my $attr (@{$self->{hash_attr}->{$name}}) {
					if (exists $attr->{comments}) {
						$attr->{comments} = [ ${$attr->{comments}}[-1] ];
					}
				}
			}
		}
	}
}

sub _cross_ref {
	my $self = shift;
	my($flag_zombi) = @_;

	while (my($name, $decl) = each %{$self->{hash_element}}) {
		my $model = $decl->{Model};
		while ($model) {
			for ($model) {
				s/^[ \n\r\t\f\013]+//;							# whitespaces

				s/^[\?\*\+\(\),\|]//
						and last;
				s/^EMPTY//
						and last;
				s/^ANY//
						and last;
				s/^#PCDATA//
						and last;
				s/^([A-Za-z_:][0-9A-Za-z\.\-_:]*)//
						and $self->{hash_element}->{$name}->{uses}->{$1} = 1,
						and $self->{hash_element}->{$1}->{used_by}->{$name} = 1,
						    last;
				s/^([\S]+)//
						and warn __PACKAGE__,":_cross_ref INTERNAL_ERROR $1\n",
						    last;
			}
		}
	}

	if ($flag_zombi) {
		my $one_more_time = 1;
		while ($one_more_time) {
			$one_more_time = 0;
			while (my($elt_name, $elt_decl) = each %{$self->{hash_element}}) {
				next if ($elt_name eq $self->{root_name});
				unless (scalar keys %{$elt_decl->{used_by}}) {
					delete $self->{hash_element}->{$elt_name};
					foreach my $child (keys %{$elt_decl->{uses}}) {
						my $decl = $self->{hash_element}->{$child};
						delete $decl->{used_by}->{$elt_name};
						$one_more_time = 1;
					}
				}
			}
		}
	}
}

sub _format_content_model {
	my $self = shift;
	my ($model) = @_;
	my $str = "";
	while ($model) {
		for ($model) {
			s/^([ \n\r\t\f\013]+)//							# whitespaces
					and $str .= $1,
					    last;

			s/^([\?\*\+\(\),\|])//
					and $str .= $1,
					    last;
			s/^(EMPTY)//
					and $str .= "<span class='keyword1'>" . $1 . "</span>",
					    last;
			s/^(ANY)//
					and $str .= "<span class='keyword1'>" . $1 . "</span>",
					    last;
			s/^(#PCDATA)//
					and $str .= "<span class='keyword1'>" . $1 . "</span>",
					    last;
			s/^([A-Za-z_:][0-9A-Za-z\.\-_:]*)//
					and $str .= $self->_mk_text_anchor("elt", $1),
					    last;
			s/^([\S]+)//
					and warn __PACKAGE__,":_format_content_model INTERNAL_ERROR $1\n",
					    last;
		}
	}
	return $str;
}

sub _include_doc {
	my $self = shift;
	my($filename) = @_;
	my $doc = "";

	open IN, $filename
			or warn "can't open $filename ($!).\n",
			return $doc;

	while (<IN>) {
		$doc .= $_;
	}
	close IN;
	return $doc;
}

sub _extract_doc {
	my $self = shift;
	my($comment) = @_;
	my $doc = undef;
	my @tags = ();
	my @lines = split /\n/, $comment->{Data};
	foreach (@lines) {
		if      (/^\s*@(@?)\s*([\s0-9A-Z_a-z]+):\s*(.*)/) {
			my $href = $1;
			my $tag = $2;
			my $value = $3;
			$tag =~ s/\s*$//;
			if ($tag eq "INCLUDE") {
				$doc .= $self->_include_doc($value);
			} else {
				push @tags, [$href, $tag, $value];
			}
		} elsif (/^\s*@(@?)\s*([A-Z_a-z][0-9A-Z_a-z]*)\s+(.*)/) {
			my $href = $1;
			my $tag = $2;
			my $value = $3;
			if ($tag eq "INCLUDE") {
				$doc .= $self->_include_doc($value);
			} else {
				push @tags, [$href, $tag, $value];
			}
		} else {
			$doc .= $_;
			$doc .= "\n";
		}
	}
	return ($doc, \@tags);
}

sub _process_text {
	my $self = shift;
	my($text, $current, $href) = @_;

	# keep track of leading and trailing white-space
	my $lead  = ($text =~ s/\A(\s+)//s ? $1 : "");
	my $trail = ($text =~ s/(\s+)\Z//s ? $1 : "");

	# split at space/non-space boundaries
	my @words = split( /(?<=\s)(?=\S)|(?<=\S)(?=\s)/, $text );

	# process each word individually
	foreach my $word (@words) {
		# skip space runs
		next if ($word =~ /^\s*$/);
		next if ($word eq $current);
		if ($word =~ /^[A-Za-z_:][0-9A-Za-z\.\-_:]*$/) {
			next if ($self->{flag_href} and !$href);
			# looks like a DTD name
			if (exists $self->{hash_notation}->{$word}) {
				$word = $self->_mk_text_anchor("not", $word);
			}
			elsif (exists $self->{hash_entity}->{$word}) {
				$word = $self->_mk_text_anchor("ent", $word);
			}
			elsif (exists $self->{hash_element}->{$word}) {
				$word = $self->_mk_text_anchor("elt", $word);
			}
		} elsif ($word =~ /^\w+:\/\/\w/) {
			# looks like a URL
			# Don't relativize it: leave it as the author intended
			$word = "<a href='" . $word . "'>" . $word . "</a>";
		} elsif ($word =~ /^[\w.-]+\@[\w.-]+/) {
			# looks like an e-mail address
			$word = "<a href='mailto:" . $word . "'>" . $word . "</a>";
		}
	}

	# put everything back together
	return $lead . join('', @words) . $trail;
}

sub _mk_index_anchor {
	my $self = shift;
	my($type, $name) = @_;

	my $href = $self->_mk_index_href($type, $name);
	return "<a class='index' href='" . $href . "'>" . $name ."</a>";
}

sub _mk_text_anchor {
	my $self = shift;
	my($type, $name) = @_;

	my $href = $self->_mk_index_href($type, $name);
	return "<a href='" . $href . "'>" . $name . "</a>";
}

sub _mk_index_href {
	my $self = shift;
	my($type, $name) = @_;

	return "#" . $type . "_" . $name;
}

sub generateAlphaElement {
	my $self = shift;
	my ($nb, $a_link) = @_;

	$nb = 'nb_element' unless (defined $nb);
	$a_link = 'a_elements' unless (defined $a_link);

	my @elements = sort keys %{$self->{hash_element}};
	my @a_link = ();
	foreach (@elements) {
		my $a = $self->_mk_index_anchor("elt", $_);
		$a .= " (root)" if ($_ eq $self->{root_name});
		push @a_link, { a => $a };
	}
	$self->{template}->param(
			$nb			=> scalar @elements,
			$a_link		=> \@a_link,
	);
}

sub generateAlphaEntity {
	my $self = shift;
	my ($nb, $a_link) = @_;

	$nb = 'nb_entity' unless (defined $nb);
	$a_link = 'a_entities' unless (defined $a_link);

	my @entities = sort keys %{$self->{hash_entity}};
	my @a_link = ();
	foreach (@entities) {
		my $a = $self->_mk_index_anchor("ent", $_);
		push @a_link, { a => $a };
	}
	$self->{template}->param(
			$nb			=> scalar @entities,
			$a_link		=> \@a_link,
	);
}

sub generateAlphaNotation {
	my $self = shift;
	my ($nb, $a_link) = @_;

	$nb = 'nb_notation' unless (defined $nb);
	$a_link = 'a_notations' unless (defined $a_link);

	my @notations = sort keys %{$self->{hash_notation}};
	my @a_link = ();
	foreach (@notations) {
		my $a = $self->_mk_index_anchor("not", $_);
		push @a_link, { a => $a };
	}
	$self->{template}->param(
			$nb			=> scalar @notations,
			$a_link		=> \@a_link,
	);
}

sub generateExampleIndex {
	my $self = shift;
	my ($nb, $a_link) = @_;

	$nb = 'nb_example' unless (defined $nb);
	$a_link = 'a_examples' unless (defined $a_link);

	my @examples = @{$self->{examples}};
	my @a_link = ();
	foreach (@examples) {
		my $a = $self->_mk_index_anchor("ex", $_);
		push @a_link, { a => $a };
	}
	$self->{template}->param(
			$nb			=> scalar @examples,
			$a_link		=> \@a_link,
	);
}

sub _mk_tree {
	my $self = shift;
	my ($name) = @_;
	my %done = ();

	return if ($self->{hash_element}->{$name}->{done});
	$self->{hash_element}->{$name}->{done} = 1;
	die __PACKAGE__,"_mk_tree: INTERNAL ERROR ($name).\n"
			unless (defined $self->{hash_element}->{$name}->{uses});
	return unless (scalar keys %{$self->{hash_element}->{$name}->{uses}});

	$self->{_tree} .= "<ul class='tree'>\n";
	foreach (keys %{$self->{hash_element}->{$name}->{uses}}) {
		next if ($_ eq $name);
		next if (exists $done{$_});
		$done{$_} = 1;
		$self->{_tree} .= "  <li class='tree'>" . $self->_mk_index_anchor("elt",$_) . "\n";
		$self->_mk_tree($_);
		$self->{_tree} .= "  </li>\n";
	}
	$self->{_tree} .= "</ul>\n";
}

sub generateTree {
	my $self = shift;

	$self->{_tree} = "<ul class='tree'>\n";
	$self->{_tree} .= "  <li class='tree'>" . $self->_mk_index_anchor("elt", $self->{root_name}) . "\n";
	if (exists $self->{hash_element}->{$self->{root_name}}) {
		$self->_mk_tree($self->{root_name});
	} else {
		warn "$self->{root_name} declared in DOCTYPE is an unknown element.\n";
	}
	$self->{_tree} .= "  </li>\n";
	$self->{_tree} .= "</ul>\n";
	$self->{template}->param(
			tree		=> $self->{_tree},
	);
	delete $self->{_tree};
}

sub _get_doc {
	my $self = shift;
	my ($decl) = @_;

	my $name = $decl->{Name};
	my @doc = ();
	my @tag = ();
	if (exists $decl->{comments}) {
		foreach my $comment (@{$decl->{comments}}) {
			my ($doc, $r_tags) = $self->_extract_doc($comment);
			if (defined $doc) {
				my $data = $self->_process_text($doc, $name);
				push @doc, { data => $data };
			}
			foreach (@{$r_tags}) {
				my ($href, $entry, $data) = @{$_};
				unless ($entry eq "BRIEF") {
					$data = $self->_process_text($data, $name, $href);
					push @tag, {
							entry	=> $entry,
							data	=> $data,
					};
				}
			}
		}
	}

	return (\@doc, \@tag);
}

sub _get_doc_attrs {
	my $self = shift;
	my ($name) = @_;

	my @doc_attrs = ();
	if (exists $self->{hash_attr}->{$name}) {
		foreach my $attr (@{$self->{hash_attr}->{$name}}) {
			if (exists $attr->{comments}) {
				my @doc = ();
				my @tag = ();
				foreach my $comment (@{$attr->{comments}}) {
					my ($doc, $r_tags) = $self->_extract_doc($comment);
					if (defined $doc) {
						my $data = $self->_process_text($doc, $name);
						push @doc, { data => $data };
					}
					foreach (@{$r_tags}) {
						my ($href, $entry, $data) = @{$_};
						unless ($entry eq "BRIEF") {
							$data = $self->_process_text($data, $name, $href);
							push @tag, {
									entry	=> $entry,
									data	=> $data,
							};
						}
					}
				}
				push @doc_attrs, {
						name		=> $attr->{aName},
						doc			=> [ @doc ],
						tag			=> [ @tag ],
				}
			}
		}
	}

	return \@doc_attrs;
}

sub generateMain {
	my $self = shift;

	my $standalone = "";
	my $version;
	my $encoding;
	if (defined $self->{xml_decl}) {
		$standalone = $self->{xml_decl}->{Standalone};
		$version = $self->{xml_decl}->{Version};
		$encoding = $self->{xml_decl}->{Encoding};
	}
	my $decl = $self->{dtd};
	my $name = $decl->{Name};
	my ($r_doc, $r_tag) = $self->_get_doc($decl);
	$self->{template}->param(
			dtd			=> "<a href='#elt_" . $name . "'>" . $name . "</a>",
			standalone	=> ($standalone eq "yes"),
			version		=> $version,
			encoding	=> $encoding,
			publicId	=> $decl->{PublicId},
			systemId	=> $decl->{SystemId},
			doc			=> $r_doc,
			tag			=> $r_tag,
	);

	my  @decls = ();
	foreach my $decl (@{$self->{list_decl}}) {
		my $type = $decl->{type};
		my $name = $decl->{Name};
		($r_doc, $r_tag) = $self->_get_doc($decl);
		if      ($type eq "notation") {
			push @decls, {
					is_notation			=> 1,
					is_internal_entity	=> 0,
					is_external_entity	=> 0,
					is_element			=> 0,
					name				=> $name,
					a					=> "<a id='not_" . $name . "' name='not_" . $name . "'/>",
					publicId			=> $decl->{PublicId},
					systemId			=> $decl->{SystemId},
					both_id				=> defined($decl->{PublicId}) && defined($decl->{SystemId}),
					doc					=> $r_doc,
					tag					=> $r_tag,
			};
		} elsif ($type eq "internal_entity") {
			push @decls, {
					is_notation			=> 0,
					is_internal_entity	=> 1,
					is_external_entity	=> 0,
					is_element			=> 0,
					name				=> $name,
					a					=> "<a id='ent_" . $name . "' name='ent_" . $name . "'/>",
					value				=> "&amp;#" . ord $decl->{Value} . ";",
					doc					=> $r_doc,
					tag					=> $r_tag,
			};
		} elsif ($type eq "external_entity") {
			push @decls, {
					is_notation			=> 0,
					is_internal_entity	=> 0,
					is_external_entity	=> 1,
					is_element			=> 0,
					name				=> $name,
					a					=> "<a id='ent_" . $name . "' name='ent_" . $name . "'/>",
					publicId			=> $decl->{PublicId},
					systemId			=> $decl->{SystemId},
					doc					=> $r_doc,
					tag					=> $r_tag,
			};
		} elsif ($type eq "element") {
			my $model = $decl->{Model};
			my @attrs = ();
			if (exists $self->{hash_attr}->{$name}) {
				foreach my $attr (@{$self->{hash_attr}->{$name}}) {
					my $type = $attr->{Type};
					my $tokenized_type =  $type eq "CDATA"
					                   || $type eq "ID"
					                   || $type eq "IDREF"
					                   || $type eq "IDREFS"
					                   || $type eq "ENTITY"
					                   || $type eq "ENTITIES"
					                   || $type eq "NMTOKEN"
					                   || $type eq "NMTOKENS";
					push @attrs, {
							name				=> $name,
							attr_name			=> $attr->{aName},
							type				=> $type,
							tokenized_type		=> $tokenized_type,
							value_default		=> $attr->{ValueDefault},
							value				=> $attr->{Value},
					};
				}
			}
			push @decls, {
					is_notation			=> 0,
					is_internal_entity	=> 0,
					is_external_entity	=> 0,
					is_element			=> 1,
					name				=> $name,
					a					=> "<a id='elt_" . $name . "' name='elt_" . $name . "'/>",
					model				=> $self->_format_content_model($model),
					attrs				=> \@attrs,
					doc					=> $r_doc,
					tag					=> $r_tag,
					doc_attrs			=> $self->_get_doc_attrs($name),
			};
		} else {
			warn __PACKAGE__,":generateMain INTERNAL_ERROR (type:$type)\n";
		}
	}
	$self->{template}->param(
			decls		=> \@decls,
	);
}

sub _process_example {
	my $self = shift;
	my($text) = @_;

	# keep track of leading and trailing white-space
	my $lead  = ($text =~ s/\A(\s+)//s ? $1 : "");
	my $trail = ($text =~ s/(\s+)\Z//s ? $1 : "");

	# split at space/non-space boundaries
	my @words = split( /(?<=\s)(?=\S)|(?<=\S)(?=\s)/, $text );

	# process each word individually
	foreach my $word (@words) {
		# skip space runs
		next if $word =~ /^\s*$/;
		if ($word =~ /^&lt;([A-Za-z_:][0-9A-Za-z\.\-_:]*)(&gt;[\S]*)?$/) {
			# looks like a DTD name, in example file
			if (exists $self->{hash_notation}->{$1}) {
				$word = "&lt;" . $self->_mk_text_anchor("not", $1);
				$word .= $2 if (defined $2);
			}
			elsif (exists $self->{hash_entity}->{$1}) {
				$word = "&lt;" . $self->_mk_text_anchor("ent", $1);
				$word .= $2 if (defined $2);
			}
			elsif (exists $self->{hash_element}->{$1}) {
				$word = "&lt;" . $self->_mk_text_anchor("elt", $1);
				$word .= $2 if (defined $2);
			}
		}
	}

	# put everything back together
	return $lead . join('', @words) . $trail;
}

sub _mk_example {
	my $self = shift;
	my ($example) = @_;

	open IN, $example
			or warn "can't open $example ($!)",
			next;
	my $data;
	while (<IN>) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/&lt;!--/<cite>&lt;!--/g;
		s/--&gt;/--&gt;<\/cite>/g;
		$data .= $self->_process_example($_);
	}
	close IN;

	return $data;
}

sub generateExample {
	my $self = shift;

	my @examples = ();
	foreach my $ex (@{$self->{examples}}) {
		push @examples, {
				filename	=> $ex,
				a			=> "<a id='ex_" . $ex . "' name='ex_" . $ex . "'/>",
				text		=> $self->_mk_example($ex),
		};
	}
	$self->{template}->param(
			nb_example	=> scalar @{$self->{examples}},
			examples	=> \@examples,
	);
}

sub generateCSS {
	my $self = shift;
	my ($style) = @_;

	my $outfile = $self->{outfile};
	$outfile =~ s/(\/[^\/]+)$//;
	$outfile .= "/" . $self->{css};

	open OUT, "> $outfile.css"
			or die "can't open $outfile.css ($!)\n";
	print OUT $style;
	close OUT;
}

sub GenerateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_process_args(@_);

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      h2 {color: red}\n" .
	            "      p.comment {color: green}\n" .
	            "      span.comment {color: green}\n" .
	            "      span.keyword1 {color: teal}\n" .
	            "      span.keyword2 {color: maroon}\n";

	$self->generateCSS($style) if ($self->{css});

	my $template = "simple.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			title		=> $self->{title},
	);
	$self->generateAlphaElement();
	$self->generateAlphaEntity();
	$self->generateAlphaNotation();
	$self->generateExampleIndex();
	$self->generateTree();
	$self->generateMain();
	$self->generateExample();

	my $filename = $self->{outfile} . ".html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;
}

###############################################################################

package XML::Handler::Dtd2Html::DocumentFrame;

use base qw(XML::Handler::Dtd2Html::Document);

sub _mk_index_href {
	my $self = shift;
	my($type, $name) = @_;

	return $self->{filebase} . ".main.html#" . $type . "_" . $name;
}

sub GenerateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_process_args(@_);

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      h2 {color: red}\n" .
	            "      p.comment {color: green}\n" .
	            "      span.comment {color: green}\n" .
	            "      span.keyword1 {color: teal}\n" .
	            "      span.keyword2 {color: maroon}\n";

	$self->generateCSS($style) if ($self->{css});

	my $template = "frame.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			title		=> $self->{title},
			file		=> $self->{filebase},
	);

	my $filename = $self->{outfile} . ".html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	$template = "alpha.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			title_page	=> $self->{title} . " (Alpha)",
	);
	$self->generateAlphaElement();
	$self->generateAlphaEntity();
	$self->generateAlphaNotation();
	$self->generateExampleIndex();

	$filename = $self->{outfile} . ".alpha.html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	$self->{template}->clear_params();
	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			title_page	=> $self->{title} . " (Tree)",
	);
	$self->generateTree();

	$filename = $self->{outfile} . ".tree.html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	$template = "main.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			title		=> $self->{title},
			title_page	=> $self->{title} . " (Main)",
	);
	$self->generateMain();
	$self->generateExample();

	$filename = $self->{outfile} . ".main.html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;
}

###############################################################################

package XML::Handler::Dtd2Html::DocumentBook;

use base qw(XML::Handler::Dtd2Html::Document);

sub _get_brief {
	my $self = shift;
	my ($decl) = @_;

	if ($self->{flag_comment} and exists $decl->{comments}) {
		foreach my $comment (@{$decl->{comments}}) {
			my ($doc, $r_tags) = $self->_extract_doc($comment);
			foreach my $tag (@{$r_tags}) {
				my $entry = ${$tag}[1];
				my $data  = ${$tag}[2];
				if ($entry eq "BRIEF") {
					return $data;
				}
			}
		}
	}
	return undef;
}

sub _get_parents {
	my $self = shift;
	my ($decl) = @_;

	my @parents = ();
	foreach (sort keys %{$decl->{used_by}}) {
		push @parents, { a => $self->_mk_text_anchor("elt", $_) };
	}

	return \@parents;
}

sub _get_childs {
	my $self = shift;
	my ($decl) = @_;

	my @childs = ();
	foreach (sort keys %{$decl->{uses}}) {
		push @childs, { a => $self->_mk_text_anchor("elt", $_) };
	}

	return \@childs;
}

sub _get_attributes {
	my $self = shift;
	my ($name) = @_;

	my @attrs = ();
	if (exists $self->{hash_attr}->{$name}) {
		foreach my $attr (@{$self->{hash_attr}->{$name}}) {
			my $value_default = $attr->{ValueDefault};
			my $value = $attr->{Value};
			if ($value) {
				$value =~ s/^['"]//;
				$value =~ s/['"]$//;
				$value_default .= " " . $value;
			}
			$value_default = "&nbsp;" unless ($value_default);
			push @attrs, {
					attr_name	=> $attr->{aName},
					type		=> $attr->{Type},
					value_default	=> $value_default,
			};
		}
	}

	return \@attrs;
}

sub _mk_index_href {
	my $self = shift;
	my($type, $name) = @_;

	my $uri_name = $name;
	$uri_name =~ s/[ :]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return $self->{filebase} . "." . $type . "." . $uri_name . ".html";
}

sub _mk_nav_href {
	my $self = shift;
	my($type, $name) = @_;

	return undef unless ($name);

	return $self->_mk_index_href($type, $name);
}

sub _mk_outfile {
	my $self = shift;
	my($type, $name) = @_;

	my $uri_name = $name;
	$uri_name =~ s/[ :]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return $self->{outfile} . "." . $type . "." . $uri_name . ".html";
}

sub _test_sensitive {
	my $self = shift;
	use File::Temp qw(tempfile);

	my ($fh, $filename) = tempfile("caseXXXX");
	close $fh;
	if (-e $filename and -e uc $filename) {
		$self->{not_sensitive} = 1;
	}
	unlink $filename;
}

sub _mk_filename {
	my $self = shift;
	my ($name) = @_;
	return $name unless (exists $self->{not_sensitive});
	$name =~ s/([A-Z])/$1_/g;
	$name =~ s/([a-z])/_$1/g;
	return $name;
}

sub copyPNG {
	my $self = shift;
	use File::Copy;

	my $path = $INC{'XML/Handler/Dtd2Html.pm'};
	$path =~ s/\.pm$//i;
	my $outfile = $self->{outfile};
	$outfile =~ s/(\/[^\/]+)+$//;
	foreach my $img qw(next up home prev) {
		copy("$path/$img.png", "$outfile/$img.png");
	}
}

sub GenerateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_process_args(@_);

	$self->_test_sensitive();

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      table.synopsis {background-color: #DCDCDC}\n" .	# gainsboro
	            "      td.title {font-style: italic}\n";
	$self->generateCSS($style) if ($self->{css});
	$self->copyPNG();

	my $template = "book.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> $self->{title},
			href_next	=> $self->_mk_nav_href("", ""),
			href_prev	=> $self->_mk_nav_href("", ""),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("", ""),
			lbl_next	=> "&nbsp;",
			lbl_prev	=> "&nbsp;",
	);
	$self->{template}->param(
			href_prolog	=> $self->{filebase} . ".book." . $self->_mk_filename("prolog") . ".html",
			href_elt	=> $self->{filebase} . ".book." . $self->_mk_filename("elements_index") . ".html",
			href_ent	=> $self->{filebase} . ".book." . $self->_mk_filename("entities_index") . ".html",
			href_not	=> $self->{filebase} . ".book." . $self->_mk_filename("notations_index") . ".html",
			href_ex		=> $self->{filebase} . ".book." . $self->_mk_filename("examples_list") . ".html",
	);
	$self->generateTree();

	my $filename = $self->_mk_outfile("book", "home");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	$template = "prolog.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> $self->{title},
			href_next	=> $self->_mk_nav_href("book", "elements index"),
			href_prev	=> $self->_mk_nav_href("book", "home"),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("book", "home"),
			lbl_next	=> "elements index",
			lbl_prev	=> "home",
	);
	my ($r_doc, $r_tag) = $self->_get_doc($self->{dtd});
	$self->{template}->param(
			name		=> $self->{dtd}->{Name},
			brief		=> $self->_get_brief($self->{dtd}),
			publicId	=> $self->{dtd}->{PublicId},
			systemId	=> $self->{dtd}->{SystemId},
			doc			=> $r_doc,
			tag			=> $r_tag,
	);

	$filename = $self->_mk_outfile("book", "prolog");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	$template = "index.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> "Elements Index.",
			href_next	=> $self->_mk_nav_href("book", "entities index"),
			href_prev	=> $self->_mk_nav_href("book", "prolog"),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("book", "home"),
			lbl_next	=> "entities index",
			lbl_prev	=> "prolog",
	);
	$self->{template}->param(
			idx_elt		=> 1,
			idx_ent		=> 0,
			idx_not		=> 0,
			lst_ex		=> 0,
	);
	$self->generateAlphaElement("nb", "a_link");
	my @elements = sort keys %{$self->{hash_element}};

	$filename = $self->_mk_outfile("book", "elements_index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	if (scalar @elements) {
		$template = "element.tmpl";
		$self->{template} = new HTML::Template(
				filename	=> $template,
				path		=> $self->{path_tmpl},
				loop_context_vars => 1,
		);
		die "can't create template with $template ($!).\n"
				unless (defined $self->{template});

		$self->{template}->param(
				generator	=> $self->{generator},
				date		=> $self->{now},
				css			=> $self->{css},
				book_title	=> $self->{title},
		);

		my @prevs = @elements;
		my @nexts = @elements;
		pop @prevs;
		unshift @prevs, "elements index";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach my $name (@elements) {
			my $decl = $self->{hash_element}->{$name};
			my $type_p = $first ? "book" : "elt";
			my $type_n = "elt";
			my $prev = shift @prevs;
			my $next = shift @nexts;

			$self->{template}->param(
					page_title	=> "Element " . $name,
					href_next	=> $self->_mk_nav_href($type_n, $next),
					href_prev	=> $self->_mk_nav_href($type_p, $prev),
					href_home	=> $self->_mk_nav_href("book", "home"),
					href_up		=> $self->_mk_nav_href("book", "elements index"),
					lbl_next	=> ($next ? $next : "&nbsp;"),
					lbl_prev	=> ($prev ? $prev : "&nbsp;"),
			);
			my $model = $decl->{Model};
			($r_doc, $r_tag) = $self->_get_doc($decl);
			$self->{template}->param(
					name		=> $name,
					brief		=> $self->_get_brief($decl),
					f_model		=> $self->_format_content_model($model),
					attrs		=> $self->_get_attributes($name),
					parents		=> $self->_get_parents($decl),
					childs		=> $self->_get_childs($decl),
					doc			=> $r_doc,
					tag			=> $r_tag,
					doc_attrs	=> $self->_get_doc_attrs($name),
					is_mixed	=> ($model =~ /#PCDATA/) ? 1 : 0,
					is_element	=> ($model !~ /(ANY|EMPTY)/) ? 1 : 0,
			);

			$filename = $self->_mk_outfile($type_n, $name);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			print OUT $self->{template}->output();
			close OUT;
			$first = 0;
		}
	}

	$template = "index.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> "Entities Index.",
			href_next	=> $self->_mk_nav_href("book", "notations index"),
			href_prev	=> $self->_mk_nav_href("book", "elements index"),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("book", "home"),
			lbl_next	=> "notations index",
			lbl_prev	=> "elements index",
	);
	$self->{template}->param(
			idx_elt		=> 0,
			idx_ent		=> 1,
			idx_not		=> 0,
			lst_ex		=> 0,
	);
	my @entities = sort keys %{$self->{hash_entity}};
	$self->generateAlphaEntity("nb", "a_link");

	$filename = $self->_mk_outfile("book","entities_index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	if (scalar @entities) {
		$template = "entity.tmpl";
		$self->{template} = new HTML::Template(
				filename	=> $template,
				path		=> $self->{path_tmpl},
		);
		die "can't create template with $template ($!).\n"
				unless (defined $self->{template});

		$self->{template}->param(
				generator	=> $self->{generator},
				date		=> $self->{now},
				css			=> $self->{css},
				book_title	=> $self->{title},
		);

		my @prevs = @entities;
		my @nexts = @entities;
		pop @prevs;
		unshift @prevs, "entities index";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach (@entities) {
			my $decl = $self->{hash_entity}->{$_};
			my $type_p = $first ? "book" : "ent";
			my $type_n = "ent";
			my $prev = shift @prevs;
			my $next = shift @nexts;

			$self->{template}->param(
					page_title	=> "Entity " . $_,
					href_next	=> $self->_mk_nav_href($type_n, $next),
					href_prev	=> $self->_mk_nav_href($type_p, $prev),
					href_home	=> $self->_mk_nav_href("book", "home"),
					href_up		=> $self->_mk_nav_href("book", "entities index"),
					lbl_next	=> ($next ? $next : "&nbsp;"),
					lbl_prev	=> ($prev ? $prev : "&nbsp;"),
			);
			($r_doc, $r_tag) = $self->_get_doc($decl);
			$self->{template}->param(
					name		=> $_,
					brief		=> $self->_get_brief($decl),
					value		=> (exists $decl->{Value}) ? ord($decl->{Value}) : undef,
					publicId	=> $decl->{PublicId},
					systemId	=> $decl->{SystemId},
					doc			=> $r_doc,
					tag			=> $r_tag,
			);

			$filename = $self->_mk_outfile($type_n, $_);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			print OUT $self->{template}->output();
			close OUT;
			$first = 0;
		}
	}

	$template = "index.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> "Notations Index.",
			href_next	=> $self->_mk_nav_href("book", "examples list"),
			href_prev	=> $self->_mk_nav_href("book", "entities index"),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("book", "home"),
			lbl_next	=> "examples list",
			lbl_prev	=> "entities index",
	);
	$self->{template}->param(
			idx_elt		=> 0,
			idx_ent		=> 0,
			idx_not		=> 1,
			lst_ex		=> 0,
	);
	my @notations = sort keys %{$self->{hash_notation}};
	$self->generateAlphaNotation("nb", "a_link");

	$filename = $self->_mk_outfile("book", "notations_index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	if (scalar @notations) {
		$template = "notation.tmpl";
		$self->{template} = new HTML::Template(
				filename	=> $template,
				path		=> $self->{path_tmpl},
		);
		die "can't create template with $template ($!).\n"
				unless (defined $self->{template});

		$self->{template}->param(
				generator	=> $self->{generator},
				date		=> $self->{now},
				css			=> $self->{css},
				book_title	=> $self->{title},
		);

		my @prevs = @notations;
		my @nexts = @notations;
		pop @prevs;
		unshift @prevs, "notations_index";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach (@notations) {
			my $decl = $self->{hash_notation}->{$_};
			my $type_p = $first ? "book" : "not";
			my $type_n = "not";
			my $prev = shift @prevs;
			my $next = shift @nexts;

			$self->{template}->param(
					page_title	=> "Notation " . $_,
					href_next	=> $self->_mk_nav_href($type_n, $next),
					href_prev	=> $self->_mk_nav_href($type_p, $prev),
					href_home	=> $self->_mk_nav_href("book", "home"),
					href_up		=> $self->_mk_nav_href("book", "notations index"),
					lbl_next	=> ($next ? $next : "&nbsp;"),
					lbl_prev	=> ($prev ? $prev : "&nbsp;"),
			);
			($r_doc, $r_tag) = $self->_get_doc($decl);
			$self->{template}->param(
					name		=> $_,
					brief		=> $self->_get_brief($decl),
					publicId	=> $decl->{PublicId},
					systemId	=> $decl->{SystemId},
					doc			=> $r_doc,
					tag			=> $r_tag,
			);

			$filename = $self->_mk_outfile($type_n, $_);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			print OUT $self->{template}->output();
			close OUT;
			$first = 0;
		}
	}

	$template = "index.tmpl";
	$self->{template} = new HTML::Template(
			filename	=> $template,
			path		=> $self->{path_tmpl},
	);
	die "can't create template with $template ($!).\n"
			unless (defined $self->{template});

	$self->{template}->param(
			generator	=> $self->{generator},
			date		=> $self->{now},
			css			=> $self->{css},
			book_title	=> $self->{title},
	);
	$self->{template}->param(
			page_title	=> "Examples List.",
			href_next	=> $self->_mk_nav_href("", ""),
			href_prev	=> $self->_mk_nav_href("book", "notations index"),
			href_home	=> $self->_mk_nav_href("book", "home"),
			href_up		=> $self->_mk_nav_href("book", "home"),
			lbl_next	=> "&nbsp;",
			lbl_prev	=> "notations index",
	);
	$self->{template}->param(
			idx_elt		=> 0,
			idx_ent		=> 0,
			idx_not		=> 0,
			lst_ex		=> 1,
	);
	my @examples = @{$self->{examples}};
	$self->generateExampleIndex("nb", "a_link");

	$filename = $self->_mk_outfile("book", "examples_list");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $self->{template}->output();
	close OUT;

	if (scalar @examples) {
		$template = "example.tmpl";
		$self->{template} = new HTML::Template(
				filename	=> $template,
				path		=> $self->{path_tmpl},
		);
		die "can't create template with $template ($!).\n"
				unless (defined $self->{template});

		$self->{template}->param(
				generator	=> $self->{generator},
				date		=> $self->{now},
				css			=> $self->{css},
				book_title	=> $self->{title},
		);

		my @prevs = @examples;
		my @nexts = @examples;
		pop @prevs;
		unshift @prevs, "examples list";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach my $example (@examples) {
			my $type_p = $first ? "book" : "ex";
			my $type_n = "ex";
			my $prev = shift @prevs;
			my $next = shift @nexts;

			$self->{template}->param(
					page_title	=> "Example " . $example,
					href_next	=> $self->_mk_nav_href($type_n, $next),
					href_prev	=> $self->_mk_nav_href($type_p, $prev),
					href_home	=> $self->_mk_nav_href("book", "home"),
					href_up		=> $self->_mk_nav_href("book", "examples list"),
					lbl_next	=> ($next ? $next : "&nbsp;"),
					lbl_prev	=> ($prev ? $prev : "&nbsp;"),
			);
			$self->{template}->param(
					example		=> $self->_mk_example($example),
			);

			$filename = $self->_mk_outfile($type_n, $example);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			print OUT $self->{template}->output();
			close OUT;
			$first = 0;
		}
	}

}

1;

__END__

=head1 NAME

XML::Handler::Dtd2Html - SAX2 handler for generate a HTML documentation from a DTD

=head1 SYNOPSIS

  use XML::SAX::Expat;
  use XML::Handler::Dtd2Html;

  $handler = new XML::Handler::Dtd2Html;

  $parser = new XML::SAX::Expat(Handler => $handler, ParseParamEnt => 1);
  $doc = $parser->parse( [OPTIONS] );

  $doc->GenerateHTML( [PARAMS] );

=head1 DESCRIPTION

All comments before a declaration are captured.

All entity references inside attribute values are expanded.

=head1 AUTHOR

Francois Perrad, francois.perrad@gadz.org

=head1 SEE ALSO

dtd2html.pl

Extensible Markup Language (XML), E<lt>http://www.w3c.org/TR/REC-xmlE<gt>

=head1 COPYRIGHT

(c) 2002 Francois PERRAD, France. All rights reserved.

This program is distributed under the Artistic License.

=cut

