=head1 NAME

Class::DBI::Pg::More - Enhances Class::DBI::Pg with more goodies.

=head1 SYNOPSIS

   package MyClass;
   use base 'Class::DBI::Pg::More';
   
   __PACKAGE__->set_up_table("my_table");

   # a_date is a date column in my_table. 
   # Class::DBI::Plugin::DateFormat::Pg->has_date has been
   # called for a_date implicitly.
   my $a_date_info =  __PACKAGE__->pg_column_info('a_date')
   print $a_date_info->{type}; # prints "date"

   # an_important is an important column in my_table set to not null
   print $a_date_info->{is_nullable} ? "TRUE" : "FALSE"; # prints FALSE

=head1 DESCRIPTION

This class overrides Class::DBI::Pg C<set_up_table> method to setup more
things from the database.

It recognizes date, timestamp etc. columns and calls
C<Class::DBI::Plugin::DateTime::Pg> has_* methods on them.

It also fetches some constraint information (currently C<not null>).

=cut

use strict;
use warnings FATAL => 'all';

package Class::DBI::Pg::More;
use base 'Class::DBI::Pg';

our $VERSION = '0.04';
$Class::DBI::Weaken_Is_Available = 0;

sub _handle_pg_datetime {
	my ($class, $col, $type) = @_;
	my $func;
	if ($type eq 'date') {
		$func = "has_$type";
	} elsif ($type =~ /^(time\w*)/) {
		$func = "has_$1";
		$func .= "tz" unless $type =~ /without time zone/;
	} else {
		return;
	}
	eval "use Class::DBI::Plugin::DateTime::Pg";
	die "Unable to use CDBIP::DT::Pg: $@" if $@;
	$class->$func($col);
}

=head1 METHODS

=head2 $class->set_up_table($table, $args)

This is main entry point to the module. Please see C<Class::DBI::Pg>
documentation for its description.

This class automagically uses Class::DBI::Plugin::DateTime::Pg for date/time
fields, so you should use DateTime values with them.

=cut
sub set_up_table {
	my ($class, $table, $args) = @_;
	$class->SUPER::set_up_table($table, $args);

	my %infos;
	my $arr = $class->db_Main->selectall_arrayref(<<ENDS
SELECT column_name, data_type, is_nullable FROM information_schema.columns
	WHERE table_name = ?
ENDS
		, undef, $table);
	for my $a (@$arr) {
		my $i = { type => $a->[1] };
		$class->_handle_pg_datetime($a->[0], $a->[1]);
		$i->{is_nullable} = 1 if $a->[2] eq 'YES';
		$infos{ $a->[0] } = $i;
	}
	$class->mk_classdata("Pg_Column_Infos", \%infos);
}

sub _do_execute {
	my ($self, $sql, $arg_map, @rest) = @_;
	my @args;
	if (!(ref($self) && @$arg_map)) {
		@args = @rest;
		goto OUT;
	}
	for (my $i = 0; $i < @$arg_map; $i++) {
		my $a = $arg_map->[$i];
		push @args, $a ? $self->$a : shift @rest;
	}
	push @args, @rest;
OUT:
	my $sth = $self->$sql;
	$sth->execute(@args);
	return $sth;
}

sub _do_set_sql {
	my ($class, $name, $sql, $ex, $cb, @arg_map) = @_;
	$class->set_sql($name, $sql);
	my $f = "sql_$name";
	no strict 'refs';
	*{ "$class\::$ex\_$name" } = sub {
		return $cb->(shift()->_do_execute($f, \@arg_map, @_));
	};
}

=head2 $class->set_exec_sql($name, $sql, @arg_map)

Wraps C<Ima::DBI> C<set_sql> methods to create C<exec_$name> function
which basically calls C<execute> on C<sql_$name> handle.

C<@arg_map> provides mapping of the arguments to the exec function. It can
be used to call instance methods to get execution parameters.

For example given "update __TABLE__ set col = ? where id = ?" statement
argument map (undef, "id") tells to substitute last parameter by results of the
$self->id function.

=cut
sub set_exec_sql {
	my ($class, $name, $sql, @arg_map) = @_;
	$class->_do_set_sql($name, $sql, "exec"
			, sub { return $_[0]->rows; }, @arg_map);
}

=head2 $class->set_exec_sql($name, $sql, $slice, @arg_map)

Wraps C<Ima::DBI> C<set_sql> methods to create C<fetch_$name> function
which basically calls C<execute> and C<fetchall_arrayref> on C<sql_$name>
handle.

For description of C<$slice> parameter see DBI C<fetchall_arrayref> function.

C<@arg_map> is described above.

=cut
sub set_fetch_sql {
	my ($class, $name, $sql, $slice, @arg_map) = @_;
	$class->_do_set_sql($name, $sql, "fetch", sub {
		return $_[0]->fetchall_arrayref($slice);
	}, @arg_map);
}

=head2 $class->pg_column_info($column)

Returns column information as HASHREF. Currently supported flags are:

=over

=item type - Returns data type of the column (e.g. integer, text, date etc.).

=item is_nullable - Indicates whether the C<$column> can be null.

=back

=cut
sub pg_column_info {
	my ($class, $col) = @_;
	return $class->Pg_Column_Infos->{ $col };
}

1;

=head1 AUTHOR

	Boris Sukholitko
	CPAN ID: BOSU
	
	boriss@gmail.com
	

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

C<Class::DBI::Pg>, C<Class::DBI::Plugin::DateTime::Pg>.

=cut

