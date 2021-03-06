#!/usr/bin/perl

use strict;

use CGI qw/-utf8/;
use CGI::Carp qw(fatalsToBrowser);
use JSON::XS;

our $self                               = $ENV{SCRIPT_NAME};
our $cgi                                = new CGI;
our $path                               = $ENV{PATH_INFO};

my $count                               =($cgi->param('count') or 50);
my $result                              = $cgi->param('result');

sub slurp($;$){local $/;open my $h,"$_[0]" or die "$! - $_[0]";$_[1]?binmode $h,$_[1]:binmode $h; my $data=<$h>;close $h;$data}
sub spit($$;$){open my $h,">","$_[0]" or die "$! - $_[0]";$_[2]?binmode $h,$_[2]:binmode $h; print $h $_[1] or die "$! - $_[0]";close $h}


sub sendtext(@){
        print <<HERE,@_;
Content-type: text/plain; charset=utf-8

HERE
}
sub redirect($){
        my($location)=@_;
        print <<HERE and exit;
Status: 301
Location: $location
Content-Type: text/html; charset=utf-8

<html><body><a href=$location>$location</a></body></html>
HERE
}

sub babble($$$){
	my($order,$count,$words)=@_;
	
	my @names=@$words;
	my %names=map{$_=>1}@names;
	my %words=map{$_=>1}map{split /\s+/}@names;
	
	my $reg="."x($order-1);
	my $ending="\0";

	my $grams;
	my @starts;

	for(@names){
		my $str=$_.$ending;

		for(0..length($str)-$order){
			my $key=substr $str,$_,$order-1;
			my $val=substr $str,$_+$order-1,1;

			$grams->{$key}||=[];
			push @{ $grams->{$key} },$val;
			push @starts,$key if $_==0;
		}
	}

	sub gram(){
		my $name=$starts[rand @starts];

		while($name!~/^(.*)$ending$/){
			$name=~/($reg)$/ or die "[$name]";

			my $key=$1;
			defined $grams->{$key} or die "[$name|$key]";

			my $list=$grams->{$key};
			$name.=$list->[rand @$list];

		}

		$name=~s/$ending$//;

		return undef if not defined $name or defined $names{$name} or 0==grep{not defined $words{$_}} split /\s+/,$name;
		$name;
	}

	my(@grams,%grams);
	for(1..10000){
		my $gram=gram;
		next unless defined $gram;
		next if $grams{$gram};

		$grams{$gram}=1;
		push @grams,$gram;
		last if @grams==$count;
	}
	
	\@grams
}

if($result){
	mkdir "results";
	
	my $id=sprintf "%08x",unpack "N",pack "C4",split/\./,$ENV{REMOTE_ADDR};
	
	spit sprintf("results/%s-%s.txt",time,$id),$result;
	
	sendtext 'thank you';
	exit
}

my $order=5;

my($bad_words)=[split /\s*\n\s*/,slurp "words-neg.txt"];
my(%bad_words)=map{$_=>1} @$bad_words;

my($all_words)=[split /\s*\n\s*/,slurp "words-all.txt"];

my($fake_words)=[grep{
	length $_>4 and
	length $_<9
} @{babble $order,1000,$all_words}];

my($good_words)=[split /\s*\n\s*/,slurp "words.txt"];

my @program;
my @kinds=qw/0 0 1 1 2/;

for(1..$count){
	my $kind=$kinds[int rand @kinds];

	my $word;
	if($kind==0){
		$word=$fake_words->[rand @$fake_words];
	} elsif($kind==1){
		$word=$good_words->[rand @$good_words];
	} elsif($kind==2){
		$word=$bad_words->[rand @$bad_words];
	} else{
		die "bad kind: $kind";
	}
	
	push @program,{
		kind		=> $kind,
		word		=> ucfirst $word,
		delay		=> 0.5+0.75*rand,
		duration	=> 1.5+1.00*rand,
	};
}

sendtext encode_json \@program;

