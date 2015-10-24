#!/usr/bin/perl

use strict;
use warnings;
use DDP;

{
	package One;

	sub new {
		my ($class, $data) = @_;

		return bless { a => $data}, $class;
	}
}

{
	package Two;
	sub new {
		my ($class, $data) = @_;

		return bless { a => $data}, $class;
	}
}

my $one = One->new("data");
my $two = Two->new("something");
$one->{b} = $two;

p $one;


my $clone->{a} = $one->{a};
$clone->{b} = $one->{b};

p $clone;

print "Теперь:\n";

$clone->{b}->{a} = '4';


p $one;
p $clone;