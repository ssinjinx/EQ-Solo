use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);
use lib $ENV{REWARD_PLUGIN_PATH};
use EQDreamTavernRewards;
{
 package Mock;
 sub new {my ($class,%args)=@_;bless \%args,$class}
 sub IsClient {1} sub CharacterID {$_[0]->{char} || 7}
 sub GetNPCTypeID {$_[0]->{id} || 100}
 sub GetHP {$_[0]->{hp}//-1}
 sub GetOwnerID {$_[0]->{pet} || 0} sub IsCharmed {0} sub GetSwarmOwner {0}
 sub GetClass {$_[0]->{class} || 1}
 sub IsRaidTarget {$_[0]->{raid} || 0} sub IsRareSpawn {$_[0]->{rare} || 0}
 sub GetName {$_[0]->{name} || 'a_rat'}
 sub Message {push @{$_[0]->{messages}},$_[2]}
}
my $root=tempdir(CLEANUP=>1);mkdir "$root/pending";mkdir "$root/receipts";
local $EQDreamTavernRewards::ROOT=$root;
my $c=Mock->new();my $n=Mock->new(rare=>1);
is(EQDreamRelease::role($n),'normal','normal encounter initialization excludes dead NPCs');
is(EQDreamTavernRewards::killed_merit($c,$n),1,'dead named queues first kill');
is(EQDreamTavernRewards::killed_merit($c,$n),0,'pending duplicate ignored');
open my $f,'<',"$root/pending/7-100.json" or die $!;local $/;my $e=decode_json(<$f>);close $f;
is($e->{kind},'named','named reward event');is($e->{characterId},7,'character identity');
rename "$root/pending/7-100.json","$root/receipts/7-100.json";
is(EQDreamTavernRewards::killed_merit($c,$n),0,'delivered duplicate ignored');
is(scalar @{$c->{messages}},1,'single notification');
is(EQDreamTavernRewards::killed_merit($c,Mock->new(id=>101,raid=>1,rare=>1)),1,'raid takes precedence');
is(EQDreamTavernRewards::killed_merit($c,Mock->new(id=>102)),0,'trash excluded');
is(EQDreamTavernRewards::killed_merit($c,Mock->new(id=>103,rare=>1,pet=>2)),0,'pets excluded');
is(EQDreamTavernRewards::killed_merit($c,Mock->new(id=>900210,raid=>1)),0,'encounter summons excluded');
is(EQDreamTavernRewards::killed_merit(Mock->new(char=>8),$n),1,'another character eligible');
done_testing();
