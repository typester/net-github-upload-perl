use Test::Base;

plan skip_all => qq{"GITHUB_LIVETEST" env required for this test}
    unless $ENV{GITHUB_LIVETEST};

plan 'no_plan';

use FindBin;
use_ok 'Config::Pit';
use_ok 'Net::GitHub::Upload';

my $repos = 'konnitiwa';

my $conf = pit_get('github.com', { required => {
    username => 'your github username',
    token    => 'your github api token',
}});

my $github = Net::GitHub::Upload->new(
    login => $conf->{username},
    token => $conf->{token},
);


my $uploaded = $github->list_files($repos);

is_deeply(
    $uploaded, $github->list_files('typester/' . $repos),
    'username auto completion ok',
);

ok(
    $github->upload(
        repos => $repos,
        name  => 'test_' . time,
        file  => "$FindBin::Bin/$FindBin::Script",
    ),
    'upload file ok'
);

ok(
    $github->upload(
        repos        => $repos,
        name         => 'test_' . time . '.txt',
        data         => 'test',
        content_type => 'text/plain',
    ),
    'upload data ok'
);

is(scalar @{ $uploaded } + 2, scalar @{$github->list_files($repos)}, 'update files ok');
