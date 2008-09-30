package Mock::CahootWebServer;

use strict;
use base qw/ Test::MockObject /;

use lib 't/lib';
use Carp;
use Digest::MD5;
use File::Slurp qw(slurp);
use URI;
use HTML::Form;

use constant STATUS => 
   { ok => 1, unavailable => 2, other_error => 3, unknown_page => 4,
     invalid_request_1 => 5, invalid_request_2 => 6 };

sub new{
   my ($class) = @_;

   my $self = $class->SUPER::new();

   $self->fake_module( 'WWW::Mechanize' );
   $self->fake_new( 'WWW::Mechanize' );

   $self->{scheme} = 'https';
   $self->{host} = 'www.cahoot.com';
   $self->{port} = 443;

   $self->{accounts} = {};
   $self->{status} = STATUS->{ok};
   $self->{progress} = 0;
   $self->{response} = {};
   $self->{session} = undef;
   $self->{md5} = Digest::MD5->new();
   $self->{pin_sel} = undef;
   $self->{pin_lock} = 0;
   $self->{pass_sel} = undef;
   $self->{pass_lock} = 0;
   $self->{account} = undef;
   $self->{logonmessage} = 0;

   $self->mock('content', sub { $_[0]->{response}{content} } );
   $self->mock('agent_alias', sub { return $_[0] } );
   $self->mock('get',
	       sub {
		 my ($self, $url) = @_;
		 $url =~ s/.*\///;
		 my $content = slurp 't/pages/'.$url;
		 $self->{content}->{$url} = $content;
		 $self->{current_url} = $url;
		 return $content;
	       });
   $self->mock('find_all_inputs',
	       sub {
		 my $content = $self->{content}->{$self->{current_url}};
		 my @names = ($content =~ m/<input.*?name="(\w+?)"/gsi);
		 my @inputs;
		 foreach my $name (@names) {
		   push @inputs, HTML::Form::Input->new(name => $name);
		 }
		 return @inputs;
	       });
   $self->mock('find_all_links',
	       sub {
		 my $content = $self->{content}->{$self->{current_url}};
		 my ($self, %opts) = @_;
		 my @urls = ($content =~ m/<$opts{tag}.*?(src|href)="(.+?)"/gsi);
		 my @links;
		 foreach my $url (@urls) {
		   next if $url eq 'src';
		   eval "use WWW::Mechanize::Link";
		   push @links, WWW::Mechanize::Link->new({ url => $url, tag => $opts{tag} });
		} 
		 return @links;
	       });
   $self->mock('follow_link',
               sub {
                 my ($self, %opts) = @_;
                 if (defined $opts{url_regex}) {
                   foreach my $link ($self->find_all_links(tag => 'a')) {
                     if ($link->url =~ $opts{url_regex}) {
                       $self->get($link->url);
                     }
                   }
                 } else {
                   carp "Only test_regex mocked for folow_link";
                 }
               });
   $self->mock('content', sub { return $self->{content}->{$self->{current_url}}; });
   $self->mock('submit_form',
	       sub {
		 my $content = $self->{content}->{$self->{current_url}};
		 $content =~ m/<form.*?action="(.+?)"/gsi;
		 $self->get($1);
		 return $self;
	       });
   $self->set_true('select');
   $self->mock('path_segments', sub { @{$_[0]->{response}{path_segments}} } );
   $self->mock('query', sub { @{$_[0]->{response}{query}} } );

   return $self;
}

1;
