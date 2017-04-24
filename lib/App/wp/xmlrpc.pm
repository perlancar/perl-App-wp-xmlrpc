package App::wp::xmlrpc;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

my %args_common = (
    proxy => {
        schema => 'str*',
        req => 1,
        tags => ['common'],
    },
    blog_id => {
        schema => 'posint*',
        default => 1,
        tags => ['common'],
    },
    username => {
        schema => 'str*',
        req => 1,
        cmdline_aliases => {u=>{}},
        tags => ['common'],
    },
    password => {
        schema => 'str*',
        req => 1,
        cmdline_aliases => {p=>{}},
        tags => ['common'],
    },
);

# for each non-common arg, if the arg's value starts with '[' or '{' then it
# will be assumed to be JSON and will be JSON-decoded.
sub _convert_args_to_struct {
    require JSON::MaybeXS;

    my $args = shift;
    for my $k (keys %$args) {
        next if $args_common{$k};
        next unless $args->{$k} =~ /\A(?:\[|\{)/;
        eval { $args->{$k} = JSON::MaybeXS::decode_json($args->{$k}) };
        die "Invalid JSON in '$k' argument: $@\n" if $@;
    }
}

sub _api {
    require XMLRPC::Lite;

    my ($args, $method, $argnames) = @_;

    my @xmlrpc_args = (
        $method,
        $args->{blog_id},
        $args->{username},
        $args->{password},
        grep {defined} map { $args->{$_} } @$argnames,
    );

    my $call = XMLRPC::Lite->proxy($args->{proxy})->call(@xmlrpc_args);
    my $fault = $call->fault;
    if ($fault && $fault->{faultCode}) {
        return [$fault->{faultCode}, $fault->{faultString}];
    }
    [200, "OK", $call->result, {'cmdline.default_format'=>'json-pretty'}];
}

our %API_Methods = (
    # Posts
    'wp.getPost' => {
        args => [
            ['post_id*', {schema=>'posint*'}],
            ['fields',   {schema=>'str*'}],
        ],
    },
    'wp.getPosts' => {
        args => [
            ['filter',   {schema=>'str*'}],
        ],
    },
    'wp.newPost' => {
        args => [
            ['content*', {schema=>'str*'}],
        ],
    },
    'wp.editPost' => {
        args => [
            ['content*', {schema=>'str*'}],
        ],
    },
    'wp.deletePost' => {
        args => [
            ['post_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getPostType' => {
        args => [
            ['post_type_name*', {schema=>'str*'}],
            ['fields', {schema=>'str*'}],
        ],
    },
    'wp.getPostTypes' => {
        args => [
            ['filter', {schema=>'str*'}],
            ['fields', {schema=>'str*'}],
        ],
    },
    'wp.getPostFormats' => {
        args => [
            ['filter', {schema=>'str*'}],
        ],
    },
    'wp.getPostStatusList' => {
        args => [
        ],
    },

    # Taxonomies
    'wp.getTaxonomy' => {
        args => [
            ['taxonomy*', {schema=>'str*'}],
        ],
    },
    'wp.getTaxonomies' => {
        args => [
        ],
    },
    'wp.getTerm' => {
        args => [
            ['taxonomy*', {schema=>'str*'}],
            ['term_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getTerms' => {
        args => [
            ['taxonomy*', {schema=>'str*'}],
        ],
    },
    'wp.newTerm' => {
        args => [
            ['content*', {schema=>'str*'}],
        ],
    },
    'wp.editTerm' => {
        args => [
            ['term_id*', {schema=>'posint*'}],
            ['content*', {schema=>'str*'}],
        ],
    },
    'wp.deleteTerm' => {
        args => [
            ['term_id*', {schema=>'posint*'}],
        ],
    },

    # Media
    'wp.getMediaItem' => {
        args => [
            ['attachment_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getMediaLibrary' => {
        args => [
            ['filter', {schema=>'str*'}],
        ],
    },
    # TODO: wp.uploadFile

    # Comments
    'wp.getCommentCount' => {
        args => [
            ['post_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getComment' => {
        args => [
            ['comment_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getComments' => {
        args => [
            ['filter', {schema=>'str*'}],
        ],
    },
    'wp.newComment' => {
        args => [
            ['post_id*', {schema=>'posint*'}],
            ['comment*', {schema=>'str*'}],
        ],
    },
    'wp.editComment' => {
        args => [
            ['comment_id*', {schema=>'posint*'}],
            ['comment*', {schema=>'str*'}],
        ],
    },
    'wp.deleteComment' => {
        args => [
            ['comment_id*', {schema=>'posint*'}],
        ],
    },
    'wp.getCommentStatusList' => {
        args => [
        ],
    },

    # Options
    'wp.getOptions' => {
        args => [
            ['options', {schema=>'str*'}],
        ],
    },
    'wp.setOptions' => {
        args => [
            ['options*', {schema=>'str*'}],
        ],
    },

    # Users
    'wp.getUsersBlogs' => {
        args => [
            ['xmlrpc*', {schema=>'str*'}],
            ['isAdmin*', {schema=>'bool*'}],
        ],
    },
    'wp.getUser' => {
        args => [
            ['user_id*', {schema=>'posint*'}],
            ['fields', {schema=>'str*'}],
        ],
    },
    'wp.getUsers' => {
        args => [
            ['fields', {schema=>'str*'}],
        ],
    },
    'wp.getProfile' => {
        args => [
            ['fields', {schema=>'str*'}],
        ],
    },
    'wp.editProfile' => {
        args => [
            ['content*', {schema=>'str*'}],
        ],
    },
    'wp.getAuthors' => {
        args => [
        ],
    },
);

GENERATE_API_FUNCTIONS: {
    no strict 'refs';
    for my $meth (sort keys %API_Methods) {
        my $apispec = $API_Methods{$meth};
        (my $funcname = $meth) =~ s/\W+/_/g;
        my $argnames = [];
        my $meta = {
            v => 1.1,
            args => {
                %args_common,
            },
        };
        my $pos = -1;
        for my $argspec (@{ $apispec->{args} }) {
            $pos++;
            my $argname = $argspec->[0];
            my $req = $argname =~ s/\*$// ? 1:0;
            push @$argnames, $argname;
            $meta->{args}{$argname} = {
                %{ $argspec->[1] },
                req => $req,
                pos => $pos,
            };
        }
        $meta->{examples} = $apispec->{examples} if $apispec->{examples};
        *{$funcname} = sub {
            my %args = @_;
            _convert_args_to_struct(\%args);
            _api(\%args, $meth, $argnames);
        };
        $SPEC{$funcname} = $meta;
    } # for $meth
} # GENERATE_API_FUNCTIONS

1;
#ABSTRACT: A thin layer of CLI over WordPress XML-RPC API

=head1 SYNOPSIS

This module is meant to be used only via the included CLI script L<wp-xmlrpc>.
If you want to make XML-RPC calls to a WordPress website, you can use
L<XMLRPC::Lite> directly, e.g. to delete a comment with ID 13:

 use XMLRPC::Lite;
 my $call = XMLRPC::Lite->proxy("http://example.org/yourblog")->call(
     "wp.deleteComment", # method
     1, # blog ID, usually just set to 1
     "username",
     "password",
     13,
 );
 my $fault = $call->fault;
 if ($fault && $fault->{faultCode}) {
     die "Can't delete comment: $fault->{faultCode} - $fault->{faultString}";
 }

To find the list of available methods and arguments, see the WordPress API
reference (see L</"SEE ALSO">).


=head1 SEE ALSO

API reference: L<https://codex.wordpress.org/XML-RPC_WordPress_API>

Other WordPress API modules on CPAN: L<WordPress::XMLRPC> by Leo Charre (a thin
wrapper over L<XMLRPC::Lite>), L<WordPress::API> by Leo Charre (an OO wrapper
over WordPress::XMLRPC, but at time of this writing the module has not been
updated since 2008/WordPress 2.7 era), L<WP::API> by Dave Rolsky (OO interface,
incomplete).

Other WordPress API CLI on CPAN: L<wordpress-info>, L<wordpress-upload-media>,
L<wordpress-upload-post> (from L<WordPress::CLI> distribution, also by Leo
Charre).

L<XMLRPC::Lite>
