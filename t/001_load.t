use strict;
use warnings FATAL => 'all';

use Test::More tests => 16;
use Test::TempDatabase;

BEGIN { use_ok( 'Class::DBI::Pg::More' ); }

my $tdb = Test::TempDatabase->create(dbname => 'ht_class_dbi_test',
		dbi_args => { RootClass => 'DBIx::ContextualFetch' });
my $dbh = $tdb->handle;
$dbh->do('SET client_min_messages TO error');
$dbh->do("CREATE TABLE table1 (id serial primary key, d1 date
		, d2 timestamp default now()
		, d3 time default now())");

package T1;
use base 'Class::DBI::Pg::More';
sub db_Main { return $dbh; }

package main;

is(T1->can('has_date'), undef);

T1->set_up_table('table1');
is_deeply([ sort T1->columns ], [ qw(d1 d2 d3 id) ]);
isnt(T1->can('has_date'), undef);

my $id_i = T1->pg_column_info('id');
isnt($id_i, undef);
is($id_i->{is_nullable}, undef);
is($id_i->{type}, 'integer');

my $d1_i = T1->pg_column_info("d1");
isnt($d1_i->{is_nullable}, undef);
is($d1_i->{type}, 'date');

my $d2_i = T1->pg_column_info("d2");
isnt($d2_i->{is_nullable}, undef);
is($d2_i->{type}, 'timestamp without time zone');

my $obj = T1->create({ d1 => DateTime->new(year => 1990, month => 8
					, day => 12) });
isnt($obj, undef);
is($obj->d1->year, 1990);
isnt($obj->d2, undef);
is($obj->d2->minute, DateTime->now->minute);
is($obj->d3->minute, DateTime->now->minute);
