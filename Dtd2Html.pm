package XML::Handler::Dtd2Html::Document;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
			xml_decl                => undef,
			doctype_decl            => undef,
			root_name               => "",
			list_decl               => [],
			hash_notation           => {},
			hash_entity             => {},
			hash_element            => {},
			hash_attr               => {}
	};
	bless($self, $class);
	return $self;
}

package XML::Handler::Dtd2Html;

use strict;

use vars qw($VERSION);

$VERSION="0.11";

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

sub start_element {
	my $self = shift;
	my ($element) = @_;
	my $name = $element->{Name};
	$self->{doc}->{root_name} = $name unless ($self->{doc}->{root_name});
}

sub end_document {
	my $self = shift;
	return $self->{doc};
}

sub comment {
	my $self = shift;
	push @{$self->{comments}}, shift;
}

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
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "unparsed_entity";
	my $name = $decl->{Name};
	$self->{doc}->{hash_entity}->{$name} = $decl;
	push @{$self->{doc}->{list_decl}}, $decl;
}

sub entity_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "entity";
	my $name = $decl->{Name};
	unless ($name =~ /^%/) {
		$self->{doc}->{hash_entity}->{$name} = $decl;
		push @{$self->{doc}->{list_decl}}, $decl;
	}
}

sub element_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$decl->{type} = "element";
	$decl->{used_by} = {};
	$decl->{uses} = [];
	my $name = $decl->{Name};
	$self->{doc}->{hash_element}->{$name} = $decl;
	push @{$self->{doc}->{list_decl}}, $decl;
}

sub attlist_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	my $elt_name = $decl->{ElementName};
	$self->{doc}->{hash_attr}->{$elt_name} = []
			unless (exists $self->{doc}->{hash_attr}->{$elt_name});
	push @{$self->{doc}->{hash_attr}->{$elt_name}}, $decl;
}

sub doctype_decl {
	my $self = shift;
	my ($decl) = @_;
	if (scalar @{$self->{comments}}) {
		$decl->{comments} = [@{$self->{comments}}];
		$self->{comments} = [];
	}
	$self->{doc}->{doctype_decl} = $decl;
	$self->{doc}->{root_name} = $decl->{Name};
}

sub xml_decl {
	my $self = shift;
	$self->{doc}->{xml_decl} = shift;
}

package XML::Handler::Dtd2Html::Document;

sub _cross_ref {
	my $self = shift;
	my($flag_zombi) = @_;

	while (my($name, $decl) = each %{$self->{hash_element}}) {
		my $model = $decl->{Model};
		while ($model) {
			for ($model) {
				s/^([ \n\r\t\f\013]+)//;							# whitespaces

				s/^([\?\*\+\(\),\|])//
						and last;
				s/^(EMPTY)//
						and last;
				s/^(ANY)//
						and last;
				s/^(#PCDATA)//
						and last;
				s/^([A-Za-z_:][0-9A-Za-z\.\-_:]*)//
						and push(@{$self->{hash_element}->{$name}->{uses}}, $1),
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
					foreach my $child (@{$elt_decl->{uses}}) {
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
	my($FH, $title, $frameset) = @_;
	my $now = localtime();
	print $FH "<?xml version='1.0' encoding='ISO-8859-1'?>\n";
	if ($frameset) {
		print $FH "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Frameset//EN' 'xhtml1-frameset.dtd'>\n";
	} else {
		print $FH "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'xhtml1-strict.dtd'>\n";
	}
	print $FH "<html xmlns='http://www.w3.org/1999/xhtml'>\n";
	print $FH "\n";
	print $FH "  <head>\n";
	print $FH "    <meta name='generator' content='dtd2html (Perl)' />\n";
	print $FH "    <meta name='date' content='",$now,"' />\n";
	print $FH "    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />\n";
	print $FH "    <title>",$title,"</title>\n";
	unless ($frameset) {
		print $FH "    <style type='text/css'>\n";
		print $FH "      h2 {color: red}\n";
		print $FH "      span.keyword1 {color: teal}\n";
		print $FH "      span.keyword2 {color: maroon}\n";
		print $FH "      p.comment {color: green}\n";
		print $FH "      span.comment {color: green}\n";
		print $FH "      hr {text-align: center}\n";
		print $FH "    </style>\n";
	}
	print $FH "  </head>\n";
	print $FH "\n";
}

sub _format_tail {
	my $self = shift;
	my($FH, $frameset) = @_;
	if ($frameset) {
		print $FH "  <noframes>\n";
		print $FH "    <body>\n";
		print $FH "      <h1>Sorry!</h1>\n";
		print $FH "      <h3>This page must be viewed by a browser that is capable of viewing frames.</h3>\n";
		print $FH "    </body>\n";
		print $FH "  </noframes>\n";
	}
	print $FH "\n";
	print $FH "</html>\n";
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
					and $str .= "<a href='#elt_" . $1 . "'>" . $1 . "</a>",
					    last;
			s/^([\S]+)//
					and warn __PACKAGE__,":_format_content_model INTERNAL_ERROR $1\n",
					    last;
		}
	}
	return $str;
}

sub _process_text {
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
		if ($word =~ /^[A-Za-z_:][0-9A-Za-z\.\-_:]*$/) {
			# looks like a DTD name
			if (exists $self->{hash_notation}->{$word}) {
				$word = "<a href='#not_" . $word . "'>" . $word . "</a>"
			}
			if (exists $self->{hash_entity}->{$word}) {
				$word = "<a href='#ent_" . $word . "'>" . $word . "</a>"
			}
			if (exists $self->{hash_element}->{$word}) {
				$word = "<a href='#elt_" . $word . "'>" . $word . "</a>"
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

sub generateAlpha {
	my $self = shift;
	my ($FH, $frameset, $outfile) = @_;

	my @elements = sort keys %{$self->{hash_element}};
	if (scalar @elements) {
		print $FH "<h2>Element index.</h2>\n";
		print $FH "<dl>\n";
		foreach (@elements) {
			if ($frameset) {
				print $FH "    <dt><a target='main' href='",$outfile,".main.html#elt_",$_,"'><b>",$_,"</b></a>";
			} else {
				print $FH "    <dt><a href='#elt_",$_,"'><b>",$_,"</b></a>";
			}
			print $FH " (root)" if ($_ eq $self->{root_name});
			print $FH "</dt>\n";
		}
		print $FH "</dl>\n";
	}
	my @entities = sort keys %{$self->{hash_entity}};
	if (scalar @entities) {
		print $FH "<h2>General Entity index.</h2>\n";
		print $FH "<dl>\n";
		foreach (@entities) {
			if ($frameset) {
				print $FH "    <dt><a target='main' href='",$outfile,".main.html#ent_",$_,"'><b>",$_,"</b></a></dt>\n";
			} else {
				print $FH "    <dt><a href='#ent_",$_,"'><b>",$_,"</b></a></dt>\n";
			}
		}
		print $FH "</dl>\n";
	}
	my @notations = sort keys %{$self->{hash_notation}};
	if (scalar @notations) {
		print $FH "<h2>Notation index.</h2>\n";
		print $FH "<dl>\n";
		foreach (@notations) {
			if ($frameset) {
				print $FH "    <dt><a target='main' href='",$outfile,".main.html#not_",$_,"'><b>",$_,"</b></a></dt>\n";
			} else {
				print $FH "    <dt><a href='#not_",$_,"'><b>",$_,"</b></a></dt>\n";
			}
		}
		print $FH "</dl>\n";
	}
}

sub _mk_tree {
	my $self = shift;
	my ($FH, $frameset, $outfile, $name) = @_;
	my %done = ();

	$self->{hash_element}->{$name}->{done} = 1;
	print $FH "<ul>\n";
	foreach (@{$self->{hash_element}->{$name}->{uses}}) {
		next if ($_ eq $name);
		next if (exists $done{$_});
		$done{$_} = 1;
		if ($frameset) {
			print $FH "  <li><a target='main' href='",$outfile,".main.html#elt_",$_,"'><b>",$_,"</b></a>\n";
		} else {
			print $FH "  <li><a href='#elt_",$_,"'><b>",$_,"</b></a>\n";
		}
		$self->_mk_tree($FH, $frameset, $outfile, $_)
				unless (exists $self->{hash_element}->{$_}->{done});
		print $FH "  </li>\n";
	}
	print $FH "</ul>\n";
}

sub generateTree {
	my $self = shift;
	my ($FH, $frameset, $outfile) = @_;

	print $FH "<h2>Element tree.</h2>\n";
	print $FH "<ul>\n";
	if ($frameset) {
		print $FH "  <li><a target='main' href='",$outfile,".main.html#elt_",$self->{root_name},"'><b>",$self->{root_name},"</b></a>\n";
	} else {
		print $FH "  <li><a href='#elt_",$self->{root_name},"'><b>",$self->{root_name},"</b></a>\n";
	}
	$self->_mk_tree($FH, $frameset, $outfile, $self->{root_name});
	print $FH "  </li>\n";
	print $FH "</ul>\n";
}

sub generateMain {
	my $self = shift;
	my ($FH, $flag_comment) = @_;

	if (defined $self->{doctype_decl}) {
		print $FH "<h3>Document entity</h3>\n";
		print $FH "<p>";
		if (defined $self->{xml_decl}) {
			my $version = $self->{xml_decl}->{Version};
			my $encoding = $self->{xml_decl}->{Encoding} || "";
			my $standalone = "";
			if (exists $self->{xml_decl}->{Standalone}) {
				$standalone = ($self->{xml_decl}->{Standalone}) ? "yes" : "no";
			}
			print $FH "&lt;<span class='keyword1'>?xml</span> ";
			print $FH "<span class='keyword1'>version</span>='<span class='keyword2'>",$version,"</span>' "
					if (defined $version);
			print $FH "<span class='keyword1'>encoding</span>='",$encoding,"' "
					if (defined $encoding);
			print $FH "<span class='keyword1'>standalone</span>='<span class='keyword2'>",$standalone,"</span>' "
					if ($standalone);
			print $FH "?&gt;\n";
			print $FH "<br />\n";
		}
		my $name = $self->{doctype_decl}->{Name};
		print $FH "&lt;<span class='keyword1'>!DOCTYPE</font> ",$name," [\n";
		print $FH "<pre>\n";
		print $FH "\t...\n";
		print $FH "]&gt;\n";
		print $FH "</pre>\n";
		print $FH "</p>\n";
		if ($flag_comment) {
			foreach my $comment (@{$self->{doctype_decl}->{comments}}) {
				my $data = $self->_process_text($comment->{Data});
				print $FH "    <p class='comment'>",$data,"</p>\n";
			}
		}
	}

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
				warn __PACKAGE__,":printToFileHandle INTERNAL_ERROR (NOTATION $name)\n";
			}
			print $FH " &gt;</p>\n";
		} elsif ($type eq "unparsed_entity") {
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
		} elsif ($type eq "entity") {
			my $value = $decl->{Value};
			my $systemId = $decl->{SystemId};
			my $publicId = $decl->{PublicId};
			my $notation = $decl->{Notation};
			print $FH "  <li>\n";
			print $FH "    <h3><a id='ent_",$name,"' name='ent_",$name,"'/>",$name,"</h3>\n";
			print $FH "<p>&lt;<span class='keyword1'>!ENTITY</span> ",$name," ";
			if (defined $value) {
				$value =~ s/&/&amp;/g;
				print $FH "'",$value,"'";
			} else {
				if (defined $publicId) {
					print $FH "<span class='keyword1'>PUBLIC</span> '",$publicId,"' '",$systemId,"'";
				} else {
					print $FH "<span class='keyword1'>SYSTEM</span> '",$systemId,"'";
				}
				print $FH "<span class='keyword1'>NDATA</span> <a href='#not_",$notation,"'>",$notation,"</a> "
						 if (defined $notation);
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
					my $attr_name = $attr->{AttributeName};
					my $type = $attr->{Type};
					my $default = $attr->{Default};
					my $fixed = $attr->{Fixed};
#					print $FH "<br/>\n";		Bug with Netscape 4.7
					print $FH "<br />\n";		# Fix
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
					print $FH " <span class='keyword2'>#FIXED</span>" if (defined $fixed);
					if ($default =~ /^#/) {
						print $FH " <span class='keyword2'>",$default,"</span>";
					} else {
						print $FH " ",$default;
					}
					print $FH " &gt;\n";
				}
			}
			print $FH "</p>\n";
		} else {
			warn __PACKAGE__,":printToFileHandle INTERNAL_ERROR (type:$type)\n";
		}
		if ($flag_comment) {
			if (exists $decl->{comments}) {
				foreach my $comment (@{$decl->{comments}}) {
					my $data = $self->_process_text($comment->{Data});
					print $FH "    <p class='comment'>",$data,"</p>\n";
				}
			}
			if ($type eq "element" and exists $self->{hash_attr}->{$name}) {
				print $FH "  <ul>\n";
				foreach my $attr (@{$self->{hash_attr}->{$name}}) {
					if (exists $attr->{comments}) {
						my $attr_name = $attr->{AttributeName};
						print $FH "    <li>",$attr_name," : <span class='comment'>\n";
						my $first = 1;
						foreach my $comment (@{$attr->{comments}}) {
							my $data = $self->_process_text($comment->{Data});
							print $FH "<p>\n" unless ($first);
							print $FH $data,"\n";
							print $FH "</p>\n" unless ($first);
							$first = 0;
						}
						print $FH "    </span></li>\n";
					}
				}
				print $FH "  </ul>\n";
			}
		}
		if ($type eq "element" and scalar keys %{$decl->{used_by}} != 0) {
			print $FH "  <p>Child of : ";
			foreach (sort keys %{$decl->{used_by}}) {
				print $FH "<a href='#elt_",$_,"'>",$_,"</a> ";
			}
			print $FH "  </p>\n";
		}
		print $FH "  </li>\n";
	}
	print $FH "</ul>\n";
}

sub generateHTML {
	my $self = shift;
	my ($outfile, $frameset, $title, $flag_comment, $flag_multi, $flag_zombi) = @_;

	$self->_cross_ref($flag_zombi);

	$title = "DTD " . $self->{root_name}
			unless (defined $title);

	if ($flag_multi) {
		foreach my $decl (@{$self->{list_decl}}) {
			if (exists $decl->{comments}) {
				$decl->{comments} = [ ${$decl->{comments}}[-1] ];
			}
		}
	}

	if (defined $frameset) {
		open OUT, "> $outfile.html"
				or die "can't open $outfile.html ($!)\n";
		$self->_format_head(\*OUT, $title, 1);
		print OUT "  <frameset cols='25%,75%'>\n";
		print OUT "    <frameset rows='50%,50%'>\n";
		print OUT "      <frame src='",$outfile,".alpha.html' id='alpha' name='alpha'/>\n";
		print OUT "      <frame src='",$outfile,".tree.html' id='tree' name='tree'/>\n";
		print OUT "    </frameset>\n";
		print OUT "    <frame src='",$outfile,".main.html' id='main' name='main'/>\n";
		print OUT "  </frameset>\n";
		$self->_format_tail(\*OUT, 1);
		close OUT;
		open OUT, "> $outfile.alpha.html"
				or die "can't open $outfile.alpha.html ($!)\n";
		$self->_format_head(\*OUT, $title . " (Index)", 0);
		print OUT "  <body>\n";
		$self->generateAlpha(\*OUT, 1, $outfile);
		print OUT "  </body>\n";
		$self->_format_tail(\*OUT, 0);
		close OUT;
		open OUT, "> $outfile.tree.html"
				or die "can't open $outfile.tree.html ($!)\n";
		$self->_format_head(\*OUT, $title . " (Tree)", 0);
		print OUT "  <body>\n";
		$self->generateTree(\*OUT, 1, $outfile);
		print OUT "  </body>\n";
		$self->_format_tail(\*OUT, 0);
		close OUT;
		open OUT, "> $outfile.main.html"
				or die "can't open $outfile.main.html ($!)\n";
		$self->_format_head(\*OUT, $title . " (Main)", 0);
		print OUT "  <body>\n";
		print OUT "    <h1>",$title,"</h1>\n";
		print OUT "    <hr />\n";
		$self->generateMain(\*OUT, $flag_comment);
		print OUT "    <hr />\n";
		print OUT "    <cite>Generated by dtd2html</cite>\n";
		print OUT "  </body>\n";
		$self->_format_tail(\*OUT, 0);
		close OUT;
	} else {
		open OUT, "> $outfile.html"
				or die "can't open $outfile.html ($!)\n";
		$self->_format_head(\*OUT, $title, 0);
		print OUT "  <body>\n";
		print OUT "    <h1>",$title,"</h1>\n";
		print OUT "    <hr />\n";
		$self->generateAlpha(\*OUT, 0);
		print OUT "    <hr />\n";
		if (scalar keys %{$self->{hash_element}}) {
			$self->generateTree(\*OUT, 0);
			print OUT "    <hr />\n";
		}
		$self->generateMain(\*OUT, $flag_comment);
		print OUT "    <hr />\n";
		print OUT "    <cite>Generated by dtd2html</cite>\n";
		print OUT "\n";
		print OUT "  </body>\n";
		print OUT "\n";
		$self->_format_tail(\*OUT, 0);
		close OUT;
	}
}

1;

__END__

=head1 NAME

XML::Handler::Dtd2Html - PerlSAX handler for generate a HTML documentation from a DTD

=head1 SYNOPSIS

  use XML::Parser::PerlSAX;
  use XML::Handler::Dtd2Html;

  $my_handler = new XML::Handler::Dtd2Html;

  $my_parser = new XML::Parser::PerlSAX(Handler => $my_handler, ParseParamEnt => 1);
  $result = $my_parser->parse( [OPTIONS] );

  $result->generateHTML($outfile, $frameset, $title);

=head1 DESCRIPTION

All comments before a declaration are captured.

All entity references inside attribute values are expanded.

=head1 AUTHOR

Francois Perrad, francois.perrad@gadz.org

=head1 SEE ALSO

PerlSAX.pod(3)

 Extensible Markup Language (XML) <http://www.w3c.org/TR/REC-xml>

=head1 COPYRIGHT

This program is distributed under the Artistic License.

=cut

