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

$VERSION="0.25";

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

sub version () {
	return $XML::Handler::Dtd2Html::VERSION;
}

sub _parse_args {
	my $self = shift;
	my ($outfile, $title, $css, $examples, $flag_comment, $flag_href, $flag_multi, $flag_zombi) = @_;

	$self->{outfile} = $outfile;

	if (defined $title) {
		$self->{title} = $title;
	} else {
		$self->{title} =  "DTD " . $self->{root_name};
	}

	$self->{css} = $css;
	$self->{examples} = $examples;
	$self->{filebase} = $outfile;
	$self->{filebase} =~ s/^([^\/]+\/)+//;
	$self->{flag_comment} = $flag_comment;
	$self->{flag_href} = $flag_href;

	$self->_cross_ref($flag_zombi);

	if ($flag_multi) {
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

sub _format_head {
	my $self = shift;
	my($FH, $title, $style, $target) = @_;
	my $now = localtime();
	print $FH "<?xml version='1.0' encoding='ISO-8859-1'?>\n";
	print $FH "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>\n";
	print $FH "<html xmlns='http://www.w3.org/1999/xhtml'>\n";
	print $FH "\n";
	print $FH "  <head>\n";
	print $FH "    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />\n";
	print $FH "    <meta name='generator' content='dtd2html ",$self->version()," (Perl ",$],")' />\n";
	print $FH "    <meta name='date' content='",$now,"' />\n";
	print $FH "    <title>",$title,"</title>\n";
	print $FH "    <base target='",$target,"' />\n" if (defined $target);
	if ($self->{css}) {
		print $FH "    <link href='",$self->{css},".css' rel='stylesheet' type='text/css'/>\n";
	} else {
		print $FH "    <style type='text/css'>\n";
		print $FH $style;
		print $FH "    </style>\n";
	}
	print $FH "  </head>\n";
	print $FH "\n";
}

sub _format_tail {
	my $self = shift;
	my($FH) = @_;
	print $FH "\n";
	print $FH "</html>\n";
}

sub _mk_model_anchor {
	my $self = shift;
	my($name) = @_;

	return "<a href='#elt_" . $name . "'>" . $name . "</a>";
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
					and $str .= $self->_mk_model_anchor($1),
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

sub _mk_text_anchor {
	my $self = shift;
	my($type, $name) = @_;

	return "<a href='#" . $type . "_" . $name . "'>" . $name . "</a>";
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

	return "<a class='index' href='#" . $type . "_" . $name . "'>" . $name ."</a>";
}

sub generateAlphaElement {
	my $self = shift;
	my ($FH, $empty) = @_;

	my @elements = sort keys %{$self->{hash_element}};
	print $FH "<h2>Elements index.</h2>\n";
	print $FH "<dl>\n";
	if (scalar @elements) {
		foreach (@elements) {
			print $FH "  <dt>",$self->_mk_index_anchor("elt",$_);
			print $FH " (root)" if ($_ eq $self->{root_name});
			print $FH "</dt>\n";
		}
	} elsif (defined $empty) {
		print $FH "  <dt>NONE</dt>\n";
	}
	print $FH "</dl>\n";
}

sub generateAlphaEntity {
	my $self = shift;
	my ($FH, $empty) = @_;

	my @entities = sort keys %{$self->{hash_entity}};
	print $FH "<h2>Entities index.</h2>\n";
	print $FH "<dl>\n";
	if (scalar @entities) {
		foreach (@entities) {
			print $FH " <dt>",$self->_mk_index_anchor("ent",$_),"</dt>\n";
		}
	} elsif (defined $empty) {
		print $FH "  <dt>NONE</dt>\n";
	}
	print $FH "</dl>\n";
}

sub generateAlphaNotation {
	my $self = shift;
	my ($FH, $empty) = @_;

	my @notations = sort keys %{$self->{hash_notation}};
	print $FH "<h2>Notations index.</h2>\n";
	print $FH "<dl>\n";
	if (scalar @notations) {
		foreach (@notations) {
			print $FH " <dt>",$self->_mk_index_anchor("not",$_),"</dt>\n";
		}
	} elsif (defined $empty) {
		print $FH "  <dt>NONE</dt>\n";
	}
	print $FH "</dl>\n";
}

sub generateExampleIndex {
	my $self = shift;
	my ($FH, $empty) = @_;

	print $FH "<h2>Examples list.</h2>\n";
	print $FH "<dl>\n";
	if (scalar @{$self->{examples}}) {
		foreach (@{$self->{examples}}) {
			print $FH " <dt>",$self->_mk_index_anchor("ex",$_),"</dt>\n";
		}
	} elsif (defined $empty) {
		print $FH "  <dt>NONE</dt>\n";
	}
	print $FH "</dl>\n";
}

sub _mk_tree {
	my $self = shift;
	my ($FH, $name) = @_;
	my %done = ();

	return if ($self->{hash_element}->{$name}->{done});
	$self->{hash_element}->{$name}->{done} = 1;
	die __PACKAGE__,"_mk_tree: INTERNAL ERROR ($name).\n"
			unless (defined $self->{hash_element}->{$name}->{uses});
	return unless (scalar keys %{$self->{hash_element}->{$name}->{uses}});

	print $FH "<ul>\n";
	foreach (keys %{$self->{hash_element}->{$name}->{uses}}) {
		next if ($_ eq $name);
		next if (exists $done{$_});
		$done{$_} = 1;
		print $FH "  <li>",$self->_mk_index_anchor("elt",$_),"\n";
		$self->_mk_tree($FH, $_);
		print $FH "  </li>\n";
	}
	print $FH "</ul>\n";
}

sub generateTree {
	my $self = shift;
	my ($FH) = @_;

	print $FH "<h2>Element tree.</h2>\n";
	print $FH "<ul>\n";
	print $FH "  <li>",$self->_mk_index_anchor("elt",$self->{root_name}),"\n";
	if (exists $self->{hash_element}->{$self->{root_name}}) {
		$self->_mk_tree($FH, $self->{root_name});
	} else {
		warn "$self->{root_name} declared in DOCTYPE is an unknown element.\n";
	}
	print $FH "  </li>\n";
	print $FH "</ul>\n";
}

sub generateComment {
	my $self = shift;
	my ($FH, $decl) = @_;

	return unless ($self->{flag_comment});

	my $type = $decl->{type};
	my $name = $decl->{Name};
	my @all_tags = ();
	if (exists $decl->{comments}) {
		foreach my $comment (@{$decl->{comments}}) {
			my ($doc, $r_tags) = $self->_extract_doc($comment);
			if (defined $doc) {
				my $data = $self->_process_text($doc, $name);
				print $FH "    <p class='comment'>",$data,"</p>\n";
			}
			push @all_tags, @{$r_tags};
		}
	}
	if ($type eq "element" and exists $self->{hash_attr}->{$name}) {
		my $nb = 0;
		foreach my $attr (@{$self->{hash_attr}->{$name}}) {
			$nb ++ if (exists $attr->{comments});
		}
		if ($nb) {
			print $FH "  <ul>\n";
			foreach my $attr (@{$self->{hash_attr}->{$name}}) {
				if (exists $attr->{comments}) {
					my $attr_name = $attr->{aName};
					my @all_attr_tags = ();
					print $FH "    <li>",$attr_name," : <span class='comment'>\n";
					my $first = 1;
					foreach my $comment (@{$attr->{comments}}) {
						my ($doc, $r_tags) = $self->_extract_doc($comment);
						if (defined $doc) {
							my $data = $self->_process_text($doc, $name);
							print $FH "<p>\n" unless ($first);
							print $FH $data,"\n";
							print $FH "</p>\n" unless ($first);
							$first = 0;
						}
						push @all_attr_tags, @{$r_tags};
					}
					print $FH "    </span>\n";
					foreach my $tag (@all_attr_tags) {
						my $href  = ${$tag}[0];
						my $entry = ${$tag}[1];
						my $data  = ${$tag}[2];
						next if ($entry eq "BRIEF");
						$data = $self->_process_text($data, $name, $href);
						print $FH "<p>",$entry," : <span class='comment'>",$data,"</span></p>\n";
					}
					print $FH "    </li>\n";
				}
			}
			print $FH "  </ul>\n";
		}
	}
	foreach my $tag (@all_tags) {
		my $href  = ${$tag}[0];
		my $entry = ${$tag}[1];
		my $data  = ${$tag}[2];
		next if ($entry eq "BRIEF");
		$data = $self->_process_text($data, $name, $href);
		print $FH "  <h4>",$entry,"</h4>\n";
		print $FH "  <p><span class='comment'>",$data,"</span></p>\n";
	}
}

sub generateMain {
	my $self = shift;
	my ($FH) = @_;

	my $standalone = "";
	print $FH "<h3>Prolog</h3>\n";
	print $FH "<p>";
	if (defined $self->{xml_decl}) {
		$standalone = $self->{xml_decl}->{Standalone};
		if ($standalone eq "yes") {
			my $version = $self->{xml_decl}->{Version};
			my $encoding = $self->{xml_decl}->{Encoding};
			print $FH "&lt;?<span class='keyword1'>xml</span> ";
			print $FH "<span class='keyword1'>version</span>='<span class='keyword2'>",$version,"</span>' "
					if (defined $version);
			print $FH "<span class='keyword1'>encoding</span>='",$encoding,"' "
					if (defined $encoding);
			print $FH "<span class='keyword1'>standalone</span>='<span class='keyword2'>",$standalone,"</span>' "
					if ($standalone);
			print $FH "?&gt;\n";
			print $FH "<br />\n";
		}
	}
	my $decl = $self->{dtd};
	my $name = $decl->{Name};
	print $FH "&lt;<span class='keyword1'>!DOCTYPE</span> <a href='#elt_",$name,"'>",$name,"</a> ";
	if ($standalone eq "yes") {
		print $FH "[\n";
		print $FH "<pre>\n";
		print $FH "\t...\n";
		print $FH "]&gt;\n";
		print $FH "</pre>\n";
	} else {
		my $publicId = $decl->{PublicId};
		my $systemId = $decl->{SystemId};
		if      (defined $publicId) {
			print $FH "<span class='keyword1'>PUBLIC</span> '",$publicId,"' '",$systemId,"'";
		} elsif (defined $systemId) {
			print $FH "<span class='keyword1'>SYSTEM</span> '",$systemId,"'";
		}
		print $FH "&gt;\n";
	}
	print $FH "</p>\n";
	$self->generateComment($FH, $decl);
	print $FH "<hr />\n";

	print $FH "<ul>\n";
	foreach my $decl (@{$self->{list_decl}}) {
		my $type = $decl->{type};
		my $name = $decl->{Name};
		if      ($type eq "notation") {
			my $publicId = $decl->{PublicId};
			my $systemId = $decl->{SystemId};
			print $FH "  <li>\n";
			print $FH "    <h3><a id='not_",$name,"' name='not_",$name,"'/>",$name,"</h3>\n";
			print $FH "<p>&lt;<span class='keyword1'>!NOTATION</span> ",$name," ";
			if      (defined $publicId and defined $systemId) {
				print $FH "<span class='keyword1'>PUBLIC</span> '",$publicId,"' '",$systemId,"'";
			} elsif (defined $publicId) {
				print $FH "<span class='keyword1'>PUBLIC</span> '",$publicId,"'";
			} elsif (defined $systemId) {
				print $FH "<span class='keyword1'>SYSTEM</span> '",$systemId,"'";
			} else {
				warn __PACKAGE__,":generateMain INTERNAL_ERROR (NOTATION $name)\n";
			}
			print $FH " &gt;</p>\n";
		} elsif ($type eq "internal_entity") {
			my $value = ord $decl->{Value};
			print $FH "  <li>\n";
			print $FH "    <h3><a id='ent_",$name,"' name='ent_",$name,"'/>",$name,"</h3>\n";
			print $FH "<p>&lt;<span class='keyword1'>!ENTITY</span> ",$name," '&amp;#",$value,";'";
			print $FH " &gt;</p>\n"
		} elsif ($type eq "external_entity") {
			my $systemId = $decl->{SystemId};
			my $publicId = $decl->{PublicId};
			print $FH "  <li>\n";
			print $FH "    <h3><a id='ent_",$name,"' name='ent_",$name,"'/>",$name,"</h3>\n";
			print $FH "<p>&lt;<span class='keyword1'>!ENTITY</span> ",$name," ";
				if (defined $publicId) {
					print $FH "<span class='keyword1'>PUBLIC</span> '",$publicId,"' '",$systemId,"'";
				} else {
					print $FH "<span class='keyword1'>SYSTEM</span> '",$systemId,"'";
				}
			print $FH " &gt;</p>\n";
		} elsif ($type eq "element") {
			next unless (exists $self->{hash_element}->{$name});
			my $model = $decl->{Model};
			my $f_model = $self->_format_content_model($model);
			print $FH "  <li>\n";
			print $FH "    <h3><a id='elt_",$name,"' name='elt_",$name,"'/>",$name,"</h3>\n";
			print $FH "<p>&lt;<span class='keyword1'>!ELEMENT</span> ",$name," ",$f_model," &gt;\n";
			if (exists $self->{hash_attr}->{$name}) {
				foreach my $attr (@{$self->{hash_attr}->{$name}}) {
					my $attr_name = $attr->{aName};
					my $type = $attr->{Type};
					my $value_default = $attr->{ValueDefault};
					my $value = $attr->{Value};
					print $FH "<br />\n";
					print $FH "&lt;<span class='keyword1'>!ATTLIST</span> ",$name;
					print $FH " ",$attr_name;
					if       ( $type eq "CDATA"
							or $type eq "ID"
							or $type eq "IDREF"
							or $type eq "IDREFS"
							or $type eq "ENTITY"
							or $type eq "ENTITIES"
							or $type eq "NMTOKEN"
							or $type eq "NMTOKENS" ) {
						print $FH " <span class='keyword1'>",$type,"</span>";
					} else {
						print $FH " ",$type;
					}
					print $FH " <span class='keyword2'>",$value_default,"</span>"
							if ($value_default);
					print $FH " ",$value
							if ($value);
					print $FH " &gt;\n";
				}
			}
			print $FH "</p>\n";
		} else {
			warn __PACKAGE__,":generateMain INTERNAL_ERROR (type:$type)\n";
		}
		$self->generateComment($FH, $decl);
		if ($type eq "element") {
			if (scalar keys %{$decl->{used_by}} != 0) {
				print $FH "  <p>Child of : ";
				foreach (sort keys %{$decl->{used_by}}) {
					print $FH "<a href='#elt_",$_,"'>",$_,"</a> ";
				}
				print $FH "  </p>\n";
			} else {
				print $FH "  <p />\n";
			}
		}
		print $FH "  </li>\n";
	}
	print $FH "</ul>\n";
}

sub _process_sample {
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

sub generateExample {
	my $self = shift;
	my ($FH,$example) = @_;

	open IN, $example
			or warn "can't open $example ($!)",
			return;
	print $FH "<pre>\n";
	while (<IN>) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/&lt;!--/<cite>&lt;!--/g;
		s/--&gt;/--&gt;<\/cite>/g;
		my $data = $self->_process_sample($_);
		print $FH $data;
	};
	close IN;
	print $FH "</pre>\n";
}

sub GenerateCSS {
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

sub generateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_parse_args(@_);

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      h2 {color: red}\n" .
	            "      p.comment {color: green}\n" .
	            "      span.comment {color: green}\n" .
	            "      span.keyword1 {color: teal}\n" .
	            "      span.keyword2 {color: maroon}\n";

	$self->GenerateCSS($style) if ($self->{css});

	open OUT, "> $self->{outfile}.html"
			or die "can't open $self->{outfile}.html ($!)\n";
	$self->_format_head(\*OUT, $self->{title}, $style);
	print OUT "  <body>\n";
	print OUT "    <h1>",$self->{title},"</h1>\n";
	print OUT "    <hr />\n";
	$self->generateAlphaElement(\*OUT);
	$self->generateAlphaEntity(\*OUT);
	$self->generateAlphaNotation(\*OUT);
	$self->generateExampleIndex(\*OUT);
	print OUT "    <hr />\n";
	$self->generateTree(\*OUT);
	print OUT "    <hr />\n";
	$self->generateMain(\*OUT);
	foreach (@{$self->{examples}}) {
		print OUT "    <hr />\n";
		print OUT "    <h3><a id='ex_",$_,"' name='ex_",$_,"'/>Example ",$_," :</h3>\n";
		$self->generateExample(\*OUT,$_);
	}
	print OUT "    <hr />\n";
	print OUT "    <div><cite>Generated by dtd2html</cite></div>\n";
	print OUT "\n";
	print OUT "  </body>\n";
	print OUT "\n";
	$self->_format_tail(\*OUT);
	close OUT;
}

###############################################################################

package XML::Handler::Dtd2Html::DocumentFrame;

@XML::Handler::Dtd2Html::DocumentFrame::ISA = qw(XML::Handler::Dtd2Html::Document);

sub _format_head {
	my $self = shift;
	my($FH) = @_;
	my $now = localtime();
	print $FH "<?xml version='1.0' encoding='ISO-8859-1'?>\n";
	print $FH "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Frameset//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd'>\n";
	print $FH "<html xmlns='http://www.w3.org/1999/xhtml'>\n";
	print $FH "\n";
	print $FH "  <head>\n";
	print $FH "    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />\n";
	print $FH "    <meta name='generator' content='dtd2html ",$self->version()," (Perl ",$],")' />\n";
	print $FH "    <meta name='date' content='",$now,"' />\n";
	print $FH "    <title>",$self->{title},"</title>\n";
	print $FH "  </head>\n";
	print $FH "\n";
}

sub _mk_index_anchor {
	my $self = shift;
	my($type, $name) = @_;

	return "<a class='index' href='" . $self->{filebase} . ".main.html#" . $type . "_" . $name ."'>" . $name . "</a>";
}

sub generateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_parse_args(@_);

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      h2 {color: red}\n" .
	            "      p.comment {color: green}\n" .
	            "      span.comment {color: green}\n" .
	            "      span.keyword1 {color: teal}\n" .
	            "      span.keyword2 {color: maroon}\n";

	$self->GenerateCSS($style) if ($self->{css});

	open OUT, "> $self->{outfile}.html"
			or die "can't open $self->{outfile}.html ($!)\n";
	$self->_format_head(\*OUT);
	print OUT "  <frameset cols='25%,75%'>\n";
	print OUT "    <frameset rows='50%,50%'>\n";
	print OUT "      <frame src='",$self->{filebase},".alpha.html' id='alpha' name='alpha'/>\n";
	print OUT "      <frame src='",$self->{filebase},".tree.html' id='tree' name='tree'/>\n";
	print OUT "    </frameset>\n";
	print OUT "    <frame src='",$self->{filebase},".main.html' id='main' name='main'/>\n";
	print OUT "    <noframes>\n";
	print OUT "      <body>\n";
	print OUT "        <h1>Sorry!</h1>\n";
	print OUT "        <h3>This page must be viewed by a browser that is capable of viewing frames.</h3>\n";
	print OUT "      </body>\n";
	print OUT "    </noframes>\n";
	print OUT "  </frameset>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	open OUT, "> $self->{outfile}.alpha.html"
			or die "can't open $self->{outfile}.alpha.html ($!)\n";
	$self->SUPER::_format_head(\*OUT, $self->{title} . " (Index)", $style, "main");
	print OUT "  <body>\n";
	$self->generateAlphaElement(\*OUT);
	$self->generateAlphaEntity(\*OUT);
	$self->generateAlphaNotation(\*OUT);
	$self->generateExampleIndex(\*OUT);
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	open OUT, "> $self->{outfile}.tree.html"
			or die "can't open $self->{outfile}.tree.html ($!)\n";
	$self->SUPER::_format_head(\*OUT, $self->{title} . " (Tree)", $style, "main");
	print OUT "  <body>\n";
	$self->generateTree(\*OUT);
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	open OUT, "> $self->{outfile}.main.html"
			or die "can't open $self->{outfile}.main.html ($!)\n";
	$self->SUPER::_format_head(\*OUT, $self->{title} . " (Main)", $style);
	print OUT "  <body>\n";
	print OUT "    <h1>",$self->{title},"</h1>\n";
	print OUT "    <hr />\n";
	$self->generateMain(\*OUT);
	foreach (@{$self->{examples}}) {
		print OUT "    <hr />\n";
		print OUT "    <h3><a id='ex_",$_,"' name='ex_",$_,"'/>Example ",$_," :</h3>\n";
		$self->generateExample(\*OUT,$_);
	}
	print OUT "    <hr />\n";
	print OUT "    <div><cite>Generated by dtd2html</cite></div>\n";
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;
}

###############################################################################

package XML::Handler::Dtd2Html::DocumentBook;

@XML::Handler::Dtd2Html::DocumentBook::ISA = qw(XML::Handler::Dtd2Html::Document);

sub _format_head {
	my $self = shift;
	my($FH, $title, $style, $links) = @_;
	my $now = localtime();
	print $FH "<?xml version='1.0' encoding='ISO-8859-1'?>\n";
	print $FH "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>\n";
	print $FH "<html xmlns='http://www.w3.org/1999/xhtml'>\n";
	print $FH "\n";
	print $FH "  <head>\n";
	print $FH "    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />\n";
	print $FH $links
			if (defined $links);
	print $FH "    <meta name='generator' content='dtd2html ",$self->version()," (Perl ",$],")' />\n";
	print $FH "    <meta name='date' content='",$now,"' />\n";
	print $FH "    <title>",$title,"</title>\n";
	if ($self->{css}) {
		print $FH "    <link href='",$self->{css},".css' rel='stylesheet' type='text/css'/>\n";
	} else {
		print $FH "    <style type='text/css'>\n";
		print $FH $style;
		print $FH "    </style>\n";
	}
	print $FH "  </head>\n";
	print $FH "\n";
}

sub _mk_model_anchor {
	my $self = shift;
	my($name) = @_;
	my $uri_name = $name;
	$uri_name =~ s/:/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return "<a href='" . $self->{filebase} . ".elt." . $uri_name . ".html'>" . $name . "</a>",
}

sub _mk_text_anchor {
	my $self = shift;
	my($type, $name) = @_;
	my $uri_name = $name;
	$uri_name =~ s/:/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return "<a href='" . $self->{filebase} . "." . $type . "." . $uri_name . ".html'>" . $name . "</a>";
}

sub _mk_nav_anchor {
	my $self = shift;
	my($type, $name, $accesskey, $label) = @_;

	return "&nbsp;" unless ($name);

	my $uri_name = $name;
	$uri_name =~ s/[ :]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return "<a href='" . $self->{filebase} . "." . $type . "." . $uri_name . ".html' accesskey='" . $accesskey . "'>" . $label . "</a>";
}

sub generatePageHeader {
	my $self = shift;
	my ($FH, $type_p, $prev, $type_n, $next) = @_;

	print $FH "<div class='navheader'>\n";
	print $FH "  <table summary='Header navigation table' width='100%' border='0' cellpadding='0' cellspacing='0'>\n";
	print $FH "    <colgroup><col width='20%'/><col width='60%'/><col width='20%'/></colgroup>\n";
	print $FH "    <tr>\n";
	print $FH "      <th colspan='3' align='center'>",$self->{title},"</th>\n";
	print $FH "    </tr>\n";
	print $FH "    <tr>\n";
	print $FH "      <td align='left' valign='bottom'>\n";
	print $FH "        ",$self->_mk_nav_anchor($type_p,$prev,"P","&lt;&lt;&lt; Previous"),"\n";
	print $FH "      </td>\n";
	print $FH "      <td align='center' valign='bottom'/>\n";
	print $FH "      <td align='right' valign='bottom'>\n";
	print $FH "        ",$self->_mk_nav_anchor($type_n,$next,"N","Next &gt;&gt;&gt;"),"\n";
	print $FH "      </td>\n";
	print $FH "    </tr>\n";
	print $FH "  </table>\n";
	print $FH "  <hr />\n";
	print $FH "</div>\n";
}

sub generatePageFooter {
	my $self = shift;
	my ($FH, $type_p, $prev, $type_n, $next, $up) = @_;

	print $FH "<div class='navfooter'>\n";
	print $FH "  <hr />\n";
	print $FH "  <table summary='Footer navigation table' width='100%' border='0' cellpadding='0' cellspacing='0'>\n";
	print $FH "    <colgroup><col width='33%'/><col width='34%'/><col width='33%'/></colgroup>\n";
	print $FH "    <tr>\n";
	print $FH "      <td align='left' valign='top'>\n";
	print $FH "        ",$self->_mk_nav_anchor($type_p,$prev,"P","&lt;&lt;&lt; Previous"),"\n";
	print $FH "      </td>\n";
	print $FH "      <td align='center' valign='top'>\n";
	print $FH "        ",$self->_mk_nav_anchor("book","home","H","Home"),"\n";
	print $FH "      </td>\n";
	print $FH "      <td align='right' valign='top'>\n";
	print $FH "        ",$self->_mk_nav_anchor($type_n,$next,"N","Next &gt;&gt;&gt;"),"\n";
	print $FH "      </td>\n";
	print $FH "    </tr>\n";
	print $FH "    <tr>\n";
	print $FH "      <td align='left' valign='top'>",($prev ? $prev : "&nbsp;"),"</td>\n";
	print $FH "      <td align='center' valign='top'>\n";
	print $FH "        ",$self->_mk_nav_anchor("book",$up,"U","Up"),"\n";
	print $FH "      </td>\n";
	print $FH "      <td align='right' valign='top'>",($next ? $next : "&nbsp;"),"</td>\n";
	print $FH "    </tr>\n";
	print $FH "    <tr>\n";
	print $FH "      <td colspan='3' align='center'><cite>--- Generated by dtd2html ---</cite></td>\n";
	print $FH "    </tr>\n";
	print $FH "  </table>\n";
	print $FH "</div>\n";
}

sub generateComment {
	my $self = shift;
	my ($FH, $decl) = @_;

	return unless ($self->{flag_comment});

	my $type = $decl->{type};
	my $name = $decl->{Name};
	my @all_tags = ();
	print $FH "<h2>Description</h2>\n";
	if (exists $decl->{comments}) {
		foreach my $comment (@{$decl->{comments}}) {
			my ($doc, $r_tags) = $self->_extract_doc($comment);
			if (defined $doc) {
				my $data = $self->_process_text($doc, $name);
				print $FH "  <p>",$data,"</p>\n";
			}
			push @all_tags, @{$r_tags};
		}
	}
	if ($type eq "element" and exists $self->{hash_attr}->{$name}) {
		my $nb = 0;
		foreach my $attr (@{$self->{hash_attr}->{$name}}) {
			$nb ++ if (exists $attr->{comments});
		}
		if ($nb) {
			print $FH "  <ul>\n";
			foreach my $attr (@{$self->{hash_attr}->{$name}}) {
				if (exists $attr->{comments}) {
					my $attr_name = $attr->{aName};
					my @all_attr_tags = ();
					print $FH "    <li><h4>",$attr_name,"</h4>\n";
					foreach my $comment (@{$attr->{comments}}) {
						my ($doc, $r_tags) = $self->_extract_doc($comment);
						if (defined $doc) {
							my $data = $self->_process_text($doc, $name);
							print $FH "      <p>",$data,"</p>\n";
						}
						push @all_attr_tags, @{$r_tags};
					}
					foreach my $tag (@all_attr_tags) {
						my $href  = ${$tag}[0];
						my $entry = ${$tag}[1];
						my $data  = ${$tag}[2];
						next if ($entry eq "BRIEF");
						$data = $self->_process_text($data, $name, $href);
						print $FH "      <h4>",$entry,"</h4>\n";
						print $FH "      <p>",$data,"</p>\n";
					}
					print $FH "    </li>\n";
				}
			}
			print $FH "  </ul>\n";
		}
	}
	foreach my $tag (@all_tags) {
		my $href  = ${$tag}[0];
		my $entry = ${$tag}[1];
		my $data  = ${$tag}[2];
		next if ($entry eq "BRIEF");
		$data = $self->_process_text($data, $name, $href);
		print $FH "  <h3>",$entry,"</h3>\n";
		print $FH "  <p>",$data,"</p>\n";
	}
}

sub generatePage {
	my $self = shift;
	my ($FH, $decl) = @_;

	my $type = $decl->{type};
	my $name = $decl->{Name};
	if      ($type eq "notation") {
		print $FH "<h1>Notation ",$name,"</h1>\n";
	} elsif ($type eq "internal_entity") {
		print $FH "<h1>Entity ",$name,"</h1>\n";
	} elsif ($type eq "external_entity") {
		print $FH "<h1>Entity ",$name,"</h1>\n";
	} elsif ($type eq "unparsed_entity") {
		print $FH "<h1>Entity ",$name,"</h1>\n";
	} elsif ($type eq "element") {
		print $FH "<h1>Element ",$name,"</h1>\n";
	} elsif ($type eq "doctype") {
		print $FH "<h1>Prolog ",$name,"</h1>\n";
	}
	print $FH "<h2>Name</h2>\n";
	print $FH "<p>",$name,"\n";
	if ($self->{flag_comment} and exists $decl->{comments}) {
		foreach my $comment (@{$decl->{comments}}) {
			my ($doc, $r_tags) = $self->_extract_doc($comment);
			foreach my $tag (@{$r_tags}) {
				my $entry = ${$tag}[1];
				my $data  = ${$tag}[2];
				if ($entry eq "BRIEF") {
					print $FH " -- ",$data;
					last;
				}
			}
		}
	}
	print $FH "</p>\n";
	print $FH "<h2>Synopsis</h2>\n";
	if      ($type eq "notation") {
		my $publicId = $decl->{PublicId};
		my $systemId = $decl->{SystemId};
		print $FH "<table class='synopsis' border='1' cellspacing='0' cellpadding='4'>\n";
		print $FH "<tr><td class='title'>Name</td>";
		if (defined $publicId) {
			print $FH "<td class='title'>Public</td>";
		}
		if (defined $systemId) {
			print $FH "<td class='title'>System</td>";
		}
		print $FH "</tr>\n";
		print $FH "<tr><td>",$name,"</td>";
		if (defined $publicId) {
			print $FH "<td>",$publicId,"</td>";
		}
		if (defined $systemId) {
			print $FH "<td>",$systemId,"</td>";
		}
		print $FH "</tr>\n";
		print $FH "</table>\n";
	} elsif ($type eq "internal_entity") {
		my $value = ord $decl->{Value};
		print $FH "<table class='synopsis' border='1' cellspacing='0' cellpadding='4'>\n";
		print $FH "<tr><td class='title'>Name</td><td class='title'>Value</td></tr>\n";
		print $FH "<tr><td>",$name,"</td><td>&#",$value,";</td></tr>\n";
		print $FH "</table>\n";
	} elsif ($type eq "external_entity") {
		my $systemId = $decl->{SystemId};
		my $publicId = $decl->{PublicId};
		print $FH "<table class='synopsis' border='1' cellspacing='0' cellpadding='4'>\n";
		print $FH "<tr><td class='title'>Name</td>";
		if (defined $publicId) {
			print $FH "<td class='title'>Public</td>";
		}
		print $FH "<td class='title'>System</td>";
		print $FH "</tr>\n";
		print $FH "<tr><td>",$name,"</td>";
		if (defined $publicId) {
			print $FH "<td>",$publicId,"</td>";
		}
		print $FH "<td>",$systemId,"</td>";
		print $FH "</tr>\n";
		print $FH "</table>\n";
	} elsif ($type eq "element") {
		my $model = $decl->{Model};
		my $type_model = "Element Content Model";
		if      ($model =~ /#PCDATA/) {
			$type_model = "Mixed Content Model";
		} elsif ($model =~ /(ANY|EMPTY)/) {
			$type_model = "Content Model";
		}
		my $f_model = $self->_format_content_model($model);
		print $FH "<table class='synopsis' border='1' cellspacing='0' cellpadding='4'>\n";
		print $FH "<tr><td class='title' colspan='3'>",$type_model,"</td></tr>\n";
		print $FH "<tr><td colspan='3'>",$name," ::= <br />",$f_model,"</td></tr>\n";
		print $FH "<tr><td class='title' colspan='3'>Attributes</td></tr>\n";
		if (exists $self->{hash_attr}->{$name}) {
			print $FH "<tr><td class='title'>Name</td><td class='title'>Type</td><td class='title'>Default</td></tr>\n";
			foreach my $attr (@{$self->{hash_attr}->{$name}}) {
				my $attr_name = $attr->{aName};
				my $type = $attr->{Type};
				my $value_default = $attr->{ValueDefault};
				my $value = $attr->{Value};
				if ($value) {
					$value =~ s/^['"]//;
					$value =~ s/['"]$//;
					$value_default .= " " . $value;
				}
				$value_default = "&nbsp;" unless ($value_default);
				print $FH "<tr><td>",$attr_name,"</td><td>",$type,"</td><td>",$value_default,"</td></tr>\n";
			}
		} else {
			print $FH "<tr><td colspan='3'>None</td></tr>\n";
		}
		print $FH "</table>\n";
	} elsif ($type eq "doctype") {
		my $publicId = $decl->{PublicId};
		my $systemId = $decl->{SystemId};
		print $FH "<table class='synopsis' border='1' cellspacing='0' cellpadding='4'>\n";
		print $FH "<tr><td class='title'>Name</td>";
		if (defined $publicId) {
			print $FH "<td class='title'>Public</td>";
		}
		if (defined $systemId) {
			print $FH "<td class='title'>System</td>";
		}
		print $FH "</tr>\n";
		print $FH "<tr><td>",$name,"</td>";
		if (defined $publicId) {
			print $FH "<td>",$publicId,"</td>";
		}
		if (defined $systemId) {
			print $FH "<td>",$systemId,"</td>";
		}
		print $FH "</tr>\n";
		print $FH "</table>\n";
	} else {
		warn __PACKAGE__,":generatePage INTERNAL_ERROR (type:$type)\n";
	}
	$self->generateComment($FH, $decl);
	print $FH "<!-- HERE, insert extra data -->\n";
	if ($type eq "element") {
		if (scalar keys %{$decl->{used_by}} != 0) {
			print $FH "<h3>Parents</h3>\n";
			print $FH "  <p>These elements contain ",$name,": ";
			my $first = 1;
			foreach (sort keys %{$decl->{used_by}}) {
				print $FH ", " unless ($first);
				print $FH $self->_mk_model_anchor($_);
				$first = 0;
			}
			print $FH ".";
			print $FH "  </p>\n";
		}
		if (scalar keys %{$decl->{uses}} != 0) {
			print $FH "<h3>Children</h3>\n";
			print $FH "  <p>The following elements occur in ",$name,": ";
			my $first = 1;
			foreach (sort keys %{$decl->{uses}}) {
				print $FH ", " unless ($first);
				print $FH $self->_mk_model_anchor($_);
				$first = 0;
			}
			print $FH ".";
			print $FH "  </p>\n";
		} else {
			print $FH "  <p />\n";
		}
	}
}

sub _mk_index_anchor {
	my $self = shift;
	my($type, $name) = @_;

	my $uri_name = $name;
	$uri_name =~ s/[:]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return "<a class='index' href='" . $self->{filebase} . "." . $type . "." . $uri_name . ".html'>" . $name ."</a>";
}

sub _mk_outfile {
	my $self = shift;
	my($type, $name) = @_;

	my $uri_name = $name;
	$uri_name =~ s/[ :]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return $self->{outfile} . "." . $type . "." . $uri_name . ".html";
}

sub _mk_link {
	my $self = shift;
	my($rel, $title, $type, $name) = @_;

	return "" unless ($name);

	my $uri_name = $name;
	$uri_name =~ s/[ :]/_/g;
	$uri_name = $self->_mk_filename($uri_name);

	return "<link rel='" . $rel . "' title='" . $title . "' href='" . $self->{filebase} . "." . $type . "." . $uri_name . ".html'/>\n";
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

sub generateHTML {
	my $self = shift;

	warn "No element declaration captured.\n"
			unless (scalar keys %{$self->{hash_element}});

	$self->_parse_args(@_);

	$self->_test_sensitive();

	my $style = "      a.index {font-weight: bold}\n" .
	            "      hr {text-align: center}\n" .
	            "      table.synopsis {background-color: #DCDCDC}\n" .	# gainsboro
	            "      td.title {font-style: italic}\n";
	my $links;

	$self->GenerateCSS($style) if ($self->{css});

	my $filename = $self->_mk_outfile("book","home");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, $self->{title}, $style);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "", "", "", "");
	print OUT "<h2><a href='",$self->{filebase},".book.",$self->_mk_filename("prolog"),".html'>Prolog</a></h2>\n";
	print OUT "<h2><a href='",$self->{filebase},".book.",$self->_mk_filename("elements_index"),".html'>Elements index.</a></h2>\n";
	print OUT "<h2><a href='",$self->{filebase},".book.",$self->_mk_filename("entities_index"),".html'>Entities index.</a></h2>\n";
	print OUT "<h2><a href='",$self->{filebase},".book.",$self->_mk_filename("notations_index"),".html'>Notations index.</a></h2>\n";
	print OUT "<h2><a href='",$self->{filebase},".book.",$self->_mk_filename("examples_list"),".html'>Examples list.</a></h2>\n";
	print OUT "<hr />\n";
	$self->generateTree(\*OUT);
	$self->generatePageFooter(\*OUT, "", "", "", "", "");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	$filename = $self->_mk_outfile("book","prolog");
	$links = $self->_mk_link("Prev", $self->{title}, "book", "home");
	$links .= $self->_mk_link("Next", "Elements index.", "book", "elements index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, $self->{title}, $style);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "book", "home", "book", "elements index");
	$self->generatePage(\*OUT, $self->{dtd});
	$self->generatePageFooter(\*OUT, "book", "home", "book", "elements index", "home");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	$filename = $self->_mk_outfile("book","elements_index");
	$links = $self->_mk_link("Prev", $self->{title}, "book", "prolog");
	$links .= $self->_mk_link("Next", "Entities index.", "book", "entities index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, "Elements Index.", $style, $links);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "book", "prolog", "book", "entities index");
	$self->generateAlphaElement(\*OUT, 1);
	$self->generatePageFooter(\*OUT, "book", "prolog", "book", "entities index", "home");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	my @elements = sort keys %{$self->{hash_element}};
	if (scalar @elements) {
		my @prevs = @elements;
		my @nexts = @elements;
		pop @prevs;
		unshift @prevs, "elements index";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach (@elements) {
			my $decl = $self->{hash_element}->{$_};
			my $type_p = $first ? "book" : "elt";
			my $type_n = "elt";
			my $prev = shift @prevs;
			my $next = shift @nexts;
			my $filename = $self->_mk_outfile($type_n,$_);
			if ($first) {
				$links = $self->_mk_link("Prev", "Elements index.", $type_p, $prev);
			} else {
				$links = $self->_mk_link("Prev", "Element " . $prev, $type_p, $prev);
			}
			$links .= $self->_mk_link("Next", "Element " . $next, $type_n, $next);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			$self->_format_head(\*OUT, "Element " . $_, $style, $links);
			print OUT "  <body>\n";
			$self->generatePageHeader(\*OUT, $type_p, $prev, $type_n, $next);
			$self->generatePage(\*OUT, $decl);
			$self->generatePageFooter(\*OUT, $type_p, $prev, $type_n, $next, "elements index");
			print OUT "  </body>\n";
			$self->_format_tail(\*OUT);
			close OUT;
			$first = 0;
		}
	}

	$filename = $self->_mk_outfile("book","entities_index");
	$links = $self->_mk_link("Prev", "Elements index.", "book", "elements index");
	$links .= $self->_mk_link("Next", "Notations index.", "book", "notations index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, "Entities Index.", $style, $links);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "book", "elements index", "book", "notations index");
	$self->generateAlphaEntity(\*OUT, 1);
	$self->generatePageFooter(\*OUT, "book", "elements index", "book", "notations index", "home");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	my @entities = sort keys %{$self->{hash_entity}};
	if (scalar @entities) {
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
			my $filename = $self->_mk_outfile($type_n,$_);
			if ($first) {
				$links = $self->_mk_link("Prev", "Entities index." , $type_p, $prev);
			} else {
				$links = $self->_mk_link("Prev", "Entity " . $prev, $type_p, $prev);
			}
			$links .= $self->_mk_link("Next", "Entity " . $next, $type_n, $next);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			$self->_format_head(\*OUT, "Entity " . $_, $style, $links);
			print OUT "  <body>\n";
			$self->generatePageHeader(\*OUT, $type_p, $prev, $type_n, $next);
			$self->generatePage(\*OUT, $decl);
			$self->generatePageFooter(\*OUT, $type_p, $prev, $type_n, $next, "entities index");
			print OUT "  </body>\n";
			$self->_format_tail(\*OUT);
			close OUT;
			$first = 0;
		}
	}

	$filename = $self->_mk_outfile("book","notations_index");
	$links = $self->_mk_link("Prev", "Entities index.", "book", "entities index");
	$links .= $self->_mk_link("Next", "Examples list.", "book", "examples list");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, "Notations Index.", $style, $links);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "book", "entities index", "book", "examples list");
	$self->generateAlphaNotation(\*OUT, 1);
	$self->generatePageFooter(\*OUT, "book", "entities index", "book", "examples list", "home");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	my @notations = sort keys %{$self->{hash_notation}};
	if (scalar @notations) {
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
			my $filename = $self->_mk_outfile($type_n,$_);
			if ($first) {
				$links = $self->_mk_link("Prev", "Notations index.", $type_p, $prev);
			} else {
				$links = $self->_mk_link("Prev", "Notation " . $prev, $type_p, $prev);
			}
			$links .= $self->_mk_link("Next", "Notation " . $next, $type_n, $next);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			$self->_format_head(\*OUT, "Notation " . $_, $style, $links);
			print OUT "  <body>\n";
			$self->generatePageHeader(\*OUT, $type_p, $prev, $type_n, $next);
			$self->generatePage(\*OUT, $decl);
			$self->generatePageFooter(\*OUT, $type_p, $prev, $type_n, $next, "notations index");
			print OUT "  </body>\n";
			$self->_format_tail(\*OUT);
			close OUT;
			$first = 0;
		}
	}

	$filename = $self->_mk_outfile("book","examples_list");
	$links = $self->_mk_link("Prev", "Notations index.", "book", "notations index");
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	$self->_format_head(\*OUT, "Examples List.", $style, $links);
	print OUT "  <body>\n";
	$self->generatePageHeader(\*OUT, "book", "notations index", "", "");
	$self->generateExampleIndex(\*OUT, 1);
	$self->generatePageFooter(\*OUT, "book", "notations index", "", "", "home");
	print OUT "  </body>\n";
	$self->_format_tail(\*OUT);
	close OUT;

	my @examples = @{$self->{examples}};
	if (scalar @examples) {
		my @prevs = @examples;
		my @nexts = @examples;
		pop @prevs;
		unshift @prevs, "examples list";
		shift @nexts;
		push @nexts, "";
		my $first = 1;
		foreach (@examples) {
			my $type_p = $first ? "book" : "ex";
			my $type_n = "ex";
			my $prev = shift @prevs;
			my $next = shift @nexts;
			my $filename = $self->_mk_outfile($type_n,$_);
			if ($first) {
				$links = $self->_mk_link("Prev", "Examples list.", $type_p, $prev);
			} else {
				$links = $self->_mk_link("Prev", "Example " . $prev, $type_p, $prev);
			}
			$links .= $self->_mk_link("Next", "Example " . $next, $type_n, $next);
			open OUT, "> $filename"
					or die "can't open $filename ($!)\n";
			$self->_format_head(\*OUT, "Example " . $_, $style, $links);
			print OUT "  <body>\n";
			$self->generatePageHeader(\*OUT, $type_p, $prev, $type_n, $next);
			print OUT "<h1>",$_,"</h1>\n";
			$self->generateExample(\*OUT, $_);
			$self->generatePageFooter(\*OUT, $type_p, $prev, $type_n, $next, "examples list");
			print OUT "  </body>\n";
			$self->_format_tail(\*OUT);
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

  $doc->generateHTML($outfile, $title, $css, $r_examples, $flag_comment, $flag_href, $flag_multi, $flag_zombi);

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

