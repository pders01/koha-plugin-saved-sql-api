package Koha::Plugin::Xyz::Paulderscheid::SavedSQLAPI::Controllers::SavedSQL;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context ();

use SQL::Abstract ();
use Try::Tiny     qw( catch try );
use Readonly      qw( Readonly );

Readonly my $SAVED_SQL_TABLE => 'saved_sql';

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $rows = _prepare_and_execute(sub { SQL::Abstract->new->select($SAVED_SQL_TABLE) })->fetchall_arrayref({});

        if (@{$rows}) {
            use Data::Dumper;
            warn Dumper $rows;
            return $c->render(status => 200, openapi => $rows);
        }

        return $c->render(status => 200, openapi => []);
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub post {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sth            = _prepare_and_execute(sub { SQL::Abstract->new->insert($SAVED_SQL_TABLE, $c->req->json) });
        my $last_insert_id = $sth->last_insert_id;
        my $row
            = _prepare_and_execute(sub { SQL::Abstract->new->select($SAVED_SQL_TABLE, '*', {id => $last_insert_id}) })
            ->fetchrow_hashref;

        if ($row) {
            return $c->render(status => 201, openapi => $row);
        }

        return $c->render(status => 500, openapi => q{});
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $id  = $c->param('id');
        my $row = _prepare_and_execute(sub { SQL::Abstract->new->select($SAVED_SQL_TABLE, '*', {id => $id}) })
            ->fetchrow_hashref;

        if ($row) {
            return $c->render(status => 200, openapi => $row);
        }

        return $c->render(status => 404, openapi => q{});
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub put {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $id = $c->param('id');

        _prepare_and_execute(sub { SQL::Abstract->new->update($SAVED_SQL_TABLE, $c->req->json, {id => $id}) });

        my $row = _prepare_and_execute(sub { SQL::Abstract->new->select($SAVED_SQL_TABLE, '*', {id => $id}) })
            ->fetchrow_hashref;

        if ($row) {
            return $c->render(status => 200, openapi => $row);
        }

        return $c->render(status => 404, openapi => q{});
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub delete {    ## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
    my $c = shift->openapi->valid_input or return;

    return try {
        my $id  = $c->param('id');
        my $row = _prepare_and_execute(sub { SQL::Abstract->new->delete($SAVED_SQL_TABLE, {id => $id}) });

        if ($row) {
            return $c->render(status => 204, openapi => q{});
        }

        return $c->render(status => 404, openapi => q{});
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub _prepare_and_execute {
    my ($stmt_maybe_sub, @bind) = @_;

    my $dbh = C4::Context->dbh;

    my ($stmt);
    if (ref $stmt_maybe_sub eq 'CODE') {
        my $sub = $stmt_maybe_sub;
        ($stmt, @bind) = &{$sub};
    }
    else {
        $stmt = $stmt_maybe_sub;
    }
    my $sth = $dbh->prepare($stmt);

    $sth->execute(@bind);

    return $sth;
}

1;
