#line 1
## ----------------------------------------------------------------------------
# Copyright (C) 2009 NZ Registry Services
## ----------------------------------------------------------------------------
package XML::Compare;

use XML::LibXML;
use Any::Moose;

our $VERSION = '0.02';
our $VERBOSE = $ENV{XML_COMPARE_VERBOSE} || 0;

my $PARSER = XML::LibXML->new();

my $has = {
    localname => {
        # not Comment, CDATASection
        'XML::LibXML::Attr' => 1,
        'XML::LibXML::Element' => 1,
    },
    namespaceURI => {
        # not Comment, Text, CDATASection
        'XML::LibXML::Attr' => 1,
        'XML::LibXML::Element' => 1,
    },
    attributes => {
        # not Attr, Comment, CDATASection
        'XML::LibXML::Element' => 1,
    },
    value => {
        # not Element, Comment, CDATASection
        'XML::LibXML::Attr' => 1,
        'XML::LibXML::Comment' => 1,
    },
    data => {
        # not Element, Attr
        'XML::LibXML::CDATASection' => 1,
        'XML::LibXML::Comment' => 1,
        'XML::LibXML::Text' => 1,
    },
};

has 'namespace_strict' =>
    is => "rw",
    isa => "Bool",
    default => 0,
    ;

has 'error' =>
    is => "rw",
    isa => "Str",
    clearer => "_clear_error",
    ;

sub _self {
    my $args = shift;
    if ( @$args == 3 ) {
	shift @$args;
    }
    else {
	__PACKAGE__->new();
    }
}

# acts almost like an assertion (either returns true or throws an exception)
sub same {
    my $self = _self(\@_);
    my ($xml1, $xml2) = @_;
    # either throws an exception, or returns true
    return $self->_compare($xml1, $xml2);;
}

sub is_same {
    my $self = _self(\@_);
    my ($xml1, $xml2) = @_;
    # catch the exception and return true or false
    $self->_clear_error;
    eval { $self->same($xml1, $xml2); };
    if ( $@ ) {
	$self->error($@);
        return 0;
    }
    return 1;
}

sub is_different {
    my $self = _self(\@_);
    my ($xml1, $xml2) = @_;
    return !$self->is_same($xml1, $xml2);
}

# private functions
sub _xpath {
    my $l = shift;
    "/".join("/",@$l);
}

sub _die {
    my ($l, $fmt, @args) = @_;
    my $msg;
    if ( @args ) {
	    $msg = sprintf $fmt, @args;
    }
    else {
	    $msg = $fmt;
    }
    die("[at "._xpath($l)."]: ".$msg);
}

sub _compare {
    my $self = shift;
    my ($xml1, $xml2) = (@_);
    if ( $VERBOSE ) {
        print '-' x 79, "\n";
        print $xml1 . ($xml1 =~ /\n\Z/ ? "" : "\n");
        print '-' x 79, "\n";
        print $xml2 . ($xml2 =~ /\n\Z/ ? "" : "\n");
        print '-' x 79, "\n";
    }

    my $parser = XML::LibXML->new();
    my $doc1 = $parser->parse_string( $xml1 );
    my $doc2 = $parser->parse_string( $xml2 );
    return $self->_are_docs_same($doc1, $doc2);
}

sub _are_docs_same {
    my $self = shift;
    my ($doc1, $doc2) = @_;
    my $ignore = $self->ignore;
    if ( $ignore and @$ignore ) {
	my $in = {};
	for my $doc ( map { $_->documentElement } $doc1, $doc2 ) {
	    my $xpc;
	    if ( my $ix = $self->ignore_xmlns ) {
		$xpc = XML::LibXML::XPathContext->new($doc);
		$xpc->registerNs($_ => $ix->{$_})
		    for keys %$ix;
	    }
	    else {
		$xpc = $doc;
	    }
	    for my $ignore_xpath ( @$ignore ) {
		$in->{$_->nodePath}=undef
		    for $xpc->findnodes( $ignore_xpath );
	    }
	}
	$self->_ignore_nodes($in);
    }
    else {
	$self->_ignore_nothing;
    }
    return $self->_are_nodes_same(
	[ $doc1->documentElement->nodeName ],
	$doc1->documentElement,
	$doc2->documentElement,
	);
}

has 'ignore' =>
    is => "rw",
    isa => "ArrayRef[Str]",
    ;

has 'ignore_xmlns' =>
    is => "rw",
    isa => "HashRef[Str]",
    ;

has '_ignore_nodes' =>
    is => "rw",
    isa => "HashRef[Undef]",
    clearer => "_ignore_nothing",
    ;

sub _are_nodes_same {
    my $self = shift;
    my ($l, $node1, $node2) = @_;
    _msg($l, "\\ got (" . ref($node1) . ", " . ref($node2) . ")");

    # firstly, check that the node types are the same
    my $nt1 = $node1->nodeType();
    my $nt2 = $node2->nodeType();
    if ( $nt1 eq $nt2 ) {
        _same($l, "nodeType=$nt1");
    }
    else {
        _outit($l, 'node types are different', $nt1, $nt2);
        _die $l, 'node types are different (%s, %s)', $nt1, $nt2;
    }

    # if these nodes are Text, compare the contents
    if ( $has->{data}{ref $node1} ) {
        my $data1 = $node1->data();
        my $data2 = $node2->data();
        # _msg($l, ": data ($data1, $data2)");
        if ( $data1 eq $data2 ) {
            _same($l, "data");
        }
        else {
            _outit($l, 'data differs', $data1, $data2);
            _die $l, 'data differs: (%s, %s)', $data1, $data2;
        }
    }

    # if these nodes are Attr, compare the contents
    if ( $has->{value}{ref $node1} ) {
        my $val1 = $node1->getValue();
        my $val2 = $node2->getValue();
        # _msg($l, ": val ($val1, $val2)");
        if ( $val1 eq $val2 ) {
            _same($l, "value");
        }
        else {
            _outit($l, 'attr node values differs', $val1, $val2);
            _die $l, "attr node values differs (%s, %s)", $val1, $val2
        }
    }

    # check that the nodes are the same name (localname())
    if ( $has->{localname}{ref $node1} ) {
        my $ln1 = $node1->localname();
        my $ln2 = $node2->localname();
        if ( $ln1 eq $ln2 ) {
            _same($l, 'localname');
        }
        else {
            _outit($l, 'node names are different', $ln1, $ln2);
            _die $l, 'node names are different: ', $ln1, $ln2;
        }
    }

    # check that the nodes are the same namespace
    if ( $has->{namespaceURI}{ref $node1} ) {
        my $ns1 = $node1->namespaceURI();
        my $ns2 = $node2->namespaceURI();
        # _msg($l, ": namespaceURI ($ns1, $ns2)");
        if ( defined $ns1 and defined $ns2 ) {
            if ( $ns1 eq $ns2 ) {
                _same($l, 'namespaceURI');
            }
            else {
                _outit($l, 'namespaceURIs are different', $node1->namespaceURI(), $node2->namespaceURI());
                _die $l, 'namespaceURIs are different: (%s, %s)', $ns1, $ns2;
            }
        }
        elsif ( !defined $ns1 and !defined $ns2 ) {
            _same($l, 'namespaceURI (not defined for either node)');
        }
        else {
	    if ( $self->namespace_strict or defined $ns1 ) {
		_outit($l, 'namespaceURIs are defined/not defined', $ns1, $ns2);
		_die $l, 'namespaceURIs are defined/not defined: (%s, %s)', ($ns1 || '[undef]'), ($ns2 || '[undef]');
	    }
        }
    }

    # check the attribute list is the same length
    if ( $has->{attributes}{ref $node1} ) {

	my $in = $self->_ignore_nodes;
        # get just the Attrs and sort them by namespaceURI:localname
        my @attr1 = sort { _fullname($a) cmp _fullname($b) }
	    grep { !$in or !exists $in->{$_->nodePath} }
		grep { defined and $_->isa('XML::LibXML::Attr') }
		    $node1->attributes();

        my @attr2 = sort { _fullname($a) cmp _fullname($b) }
	    grep { !$in or !exists $in->{$_->nodePath} }
		grep { defined and $_->isa('XML::LibXML::Attr') }
		    $node2->attributes();

        if ( scalar @attr1 == scalar @attr2 ) {
            _same($l, 'attribute length (' . (scalar @attr1) . ')');
        }
        else {
            _die $l, 'attribute list lengths differ: (%d, %d)', scalar @attr1, scalar @attr2;
        }

        # for each attribute, check they are all the same
        my $total_attrs = scalar @attr1;
        for (my $i = 0; $i < scalar @attr1; $i++ ) {
            # recurse down (either an exception will be thrown, or all are correct
            $self->_are_nodes_same( [@$l,'@'.$attr1[$i]->name], $attr1[$i], $attr2[$i] );
        }
    }

    my $in = $self->_ignore_nodes;

    # don't need to compare or care about Comments
    my @nodes1 = grep { !$in or !exists $in->{$_->nodePath} }
	grep { ! $_->isa('XML::LibXML::Comment') and
		   !($_->isa("XML::LibXML::Text") && ($_->data =~ /\A\s*\Z/))
	       }
	    $node1->childNodes();

    my @nodes2 = grep { !$in or !exists $in->{$_->nodePath} }
	grep { ! $_->isa('XML::LibXML::Comment') and
		   !($_->isa("XML::LibXML::Text") && ($_->data =~ /\A\s*\Z/))
	       } $node2->childNodes();

    # check that the nodes contain the same number of children
    if ( @nodes1 != @nodes2 ) {
        _die $l, 'different number of child nodes: (%d, %d)', scalar @nodes1, scalar @nodes2;
    }

    # foreach of it's children, compare them
    my $total_nodes = scalar @nodes1;
    for (my $i = 0; $i < $total_nodes; $i++ ) {
        # recurse down (either an exception will be thrown, or all are correct
	my $xpath_nodeName;
	my $nn = $nodes1[$i]->nodeName;
	if ( grep { $_->nodeName eq $nn }
		 @nodes1[0..$i-1, $i+1..$#nodes1] ) {
	    $nn .= "[position()=".($i+1)."]";
	}
	$nn =~ s{#text}{text()};
        $self->_are_nodes_same( [@$l,$nn], $nodes1[$i], $nodes2[$i] );
    }

    _msg($l, '/');
    return 1;
}

sub _fullname {
    my ($node) = @_;
    my $name = '';
    $name .= $node->namespaceURI() . ':' if $node->namespaceURI();
    $name .= $node->localname();
    # print "name=$name\n";
    return $name;
}

sub _same {
    my ($l, $msg) = @_;
    return unless $VERBOSE;
    print '' . ('  ' x (@$l+1)) . "= $msg\n";
}

sub _msg {
    my ($l, $msg) = @_;
    return unless $VERBOSE;
    print ' ' . ('  ' x (@$l)) ._xpath($l). " $msg\n";
}

sub _outit {
    my ($l, $msg, $v1, $v2) = @_;
    return unless $VERBOSE;
    print '' . ('  ' x @$l) . "! " ._xpath($l)." $msg:\n";
    print '' . ('  ' x @$l) . '. ' . ($v1 || '[undef]') . "\n";
    print '' . ('  ' x @$l) . '. ' . ($v2 || '[undef]') . "\n";
}

1;
__END__

#line 473

# Local Variables:
# mode:cperl
# indent-tabs-mode: f
# cperl-continued-statement-offset: 4
# cperl-brace-offset: 0
# cperl-close-paren-offset: 0
# cperl-continued-brace-offset: 0
# cperl-continued-statement-offset: 4
# cperl-extra-newline-before-brace: nil
# cperl-indent-level: 4
# cperl-indent-parens-as-block: t
# cperl-indent-wrt-brace: nil
# cperl-label-offset: -4
# cperl-merge-trailing-else: t
# End:
# vim: filetype=perl:noexpandtab:ts=3:sw=3
