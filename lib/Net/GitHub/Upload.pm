package Net::GitHub::Upload;
use Any::Moose;

our $VERSION = '0.01';

use URI;
use LWP::UserAgent;
use HTTP::Request::Common;
use Web::Scraper;
use Path::Class qw/file/;
use JSON;
require bytes;
require Crypt::SSLeay; # for https connection

has login => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has token => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has ua => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->env_proxy;
        $ua;
    },
);

has download_scraper => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;

        my $fileinfo = scraper {
            process '//h4',
                description => 'TEXT';
            process '//h4/a',
                link => '@href',
                name => 'TEXT';
            process '//p/abbr',
                date => '@title';
            process '//p/strong',
                size => 'TEXT';
        };

        my $downloads = scraper {
            process '//*[@id="manual_downloads"]/li',
                "downloads[]" => $fileinfo;
            result 'downloads';
        };
    },
);

no Any::Moose;

sub upload {
    my $self = shift;
    my $info = @_ > 1 ? {@_} : $_[0];

    die "required repository name" unless $info->{repos};
    $info->{repos} = $self->login . '/' . $info->{repos} unless $info->{repos} =~ m!/!;

    # file
    if (my $file = $info->{file}) {
        $file = $info->{file} = file($file);
        die qq[file "$file" does not exists or readable] unless -f $file && -r _;

        $info->{name} ||= $file->basename;
    }
    die qq[required 'file' or 'data' parameter to upload]
        unless $info->{file} or $info->{data};
    die qq[required 'name' parameter for filename with 'data' parameter']
        unless $info->{name};

    # check duplicate filename
    my ($already_uploaded)
        = grep { $_->{name} eq $info->{name} } @{ $self->list_files( $info->{repos} ) || []};
    if ($already_uploaded) {
        die qq[file '$already_uploaded->{name}' is already uploaded. please try different name];
    }

    my $res = $self->ua->request(
        POST "https://github.com/$info->{repos}/downloads",
        [   file_size    => $info->{file} ? $info->{file}->stat->size
                                          : bytes::length( $info->{data} ),
            content_type => $info->{content_type} || 'application/octet-stream',
            file_name    => $info->{name},
            description  => $info->{description} || '',
            login        => $self->login,
            token        => $self->token,
        ],
    );
    die qq[Failed to post file info: "@{[ $res->status_line ]}"]
        unless $res->is_success;

    my $upload_info = decode_json $res->content;

    $res = $self->ua->request(
        POST 'http://github.s3.amazonaws.com/',
        Content_Type   => 'form-data',
        'Accept-Types' => 'text/*',
        Content        => [
            Filename              => $info->{name},
            policy                => $upload_info->{policy},
            success_action_status => 201,
            key                   => $upload_info->{prefix} . $info->{name},
            AWSAccessKeyId        => $upload_info->{accesskeyid},
            'Content-Type'        => $info->{content_type}
                                     || 'application/octet-stream',
            signature => $upload_info->{signature},
            acl       => $upload_info->{acl},
            file      => [
                $info->{file} || undef,
                $info->{name},
                'Content-Type' => $upload_info->{content_type}
                                      || 'application/octet-stream',
                $info->{data} ? (Content => $info->{data}) : (),
            ],
        ],
    );

    if ($res->code == 201) {
        return 1;
    }
    else {
        die qq[Failed to upload: @{[$res->status_line]}];
    }
}

sub list_files {
    my ($self, $repos) = @_;

    die "required repository name" unless $repos;
    $repos = $self->login . '/' . $repos unless $repos =~ m!/!;

    my $uri = URI->new("https://github.com/${repos}/downloads");
    $uri->query_form(
        login => $self->login,
        token => $self->token,
    );

    my $res = $self->ua->get($uri);
    die qq[failed to list files: "@{[ $res->status_line ]}"] unless $res->is_success;

    $self->download_scraper->scrape($res->content);
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Net::GitHub::Upload - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

use Net::GitHub::Upload;

my $github = Net::GitHub::Upload->new(
    login => 'your user name',
    token => 'your api token',
);

# upload a file
$github->upload(
    repos => 'username/repository',
    file  => '/path/to/file',
);

# upload data
$github->upload(
    repos => 'username/repository',
    name => 'filename',
    data => $data,
);

=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 KAYAC Inc. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
