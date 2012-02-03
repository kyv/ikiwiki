#!/usr/bin/perl
# kev@flujos.org

# uso: [!icescrape http://gis.tv:8000]
package IkiWiki::Plugin::icescrape;

use warnings;
use strict;
use IkiWiki 3.00;

use XML::LibXML::Reader;
use LWP::Simple;
use Encode; 
use File::Basename;

my @radios;

# llamamos a los `hooks` de ikiwiki de procesamiento del plugin
sub import {
	# underlay = ficheros estaticos incluidos en el wiki
	add_underlay("javascript");
	# opicones de configuracion para el plugin 
	hook(type => "getsetup", id => "icescrape", call => \&getsetup);
	# la mayor parte de la logica del plugin, que devuelva salida de la plantilla
	hook(type => "preprocess", id => "icescrape", call => \&preprocess, scan => 1);
        # rutina que nos permita modificar toma la html saliendo de la platilla 
	hook(type => "format", id => "icescrape", call => \&format);
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => undef,
			section => "widget",
		},
}

sub preprocess (@) {
	my ($server) = $_[0] =~ /$config{wiki_file_regexp}/; # untaint
	# paremetros de cgi
	my %params=@_;
	if (! defined $server) {
		# devuelva error si no hay un audio	
		error("[icescrape] bad url");
	}
	add_link($params{page}, $server);
	add_depends($params{page}, $server);
	# optimisation: detectar modo escanear y no generar el audio 
	if (! defined wantarray) {
		return;
	}
	if (! $params{preview}) {
		#$fileurl=urlto($file, $params{destpage});
		#$audiourl=urlto($audiolink, $params{destpage});
	}
	else {
		#$fileurl="$config{url}/$file";
		#$audiourl="$config{url}/$audiolink";
	}
 	# agregar el css 'class' `icescrape`
	if (exists $params{class}) {
		$params{class}.=" radio";
	}
	else {
		$params{class}="radio";
	}

	my $attrs='';
	foreach my $attr (qw{class id}) {
		if (exists $params{$attr}) {
			$attrs.=" $attr=\"$params{$attr}\"";
		}
        }
    my $source = &get_source($server); #grap icecast xml source
    &parse_source($source);
    my $template = template("icescrape.tmpl");
    #$template->param(src => $iceurl); 
    # el usuario final puede difinir su proprio `class`	
    $template->param(class => $params{class}); 
    $template->param(RADIOS => \@radios); 
    #devolver html 
    return $template->output;
}

sub format (@) {
    # parsea y modifica salida html de `preprocess`
    my %params=@_;
    # agregar javasript a <head>
    $params{content}=include_javascript($params{page}, 1).$params{content};
    my $count = 0;
    # loop through radios, inserting javasript for each
    foreach (@radios) {
        my $string = &include_player($count); 
    	$params{content}=~s/(<div id="radio_$count".*?>)/$1$string/;
	$count++;
    }
    
    return $params{content};
}

sub include_player {
    # nuestra reproductor de audio
    # we should to this with a template
    my $i = shift;
    my $urlogg = $radios[$i]->{URL_OGG};
    my $urlmp3 = $radios[$i]->{URL_MP3};
my $string = <<STRING;
  
<script type="text/javascript">
 \$(document).ready(function(){
   \$("#jquery_jplayer_$i").jPlayer({
     ready: function () {
       \$(this).jPlayer("setMedia", {
         mp3: "$urlmp3",
         oga: "$urlogg"
       });
     },
     swfPath: "/jplayer",
     supplied: "mp3, oga",
     cssSelectorAncestor: "#jp_interface_$i" 
   });
 });
</script>

STRING
return $string; 
}

sub include_javascript ($;$) {
    # javascript necesario para el funcionamiento del plugin
    my $page=shift;
    my $absolute=shift;

    return '<script src="'.urlto('ikiwiki/jquery.min.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
        '<script src="'.urlto('ikiwiki/jquery.jplayer.min.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
	'<link href="'.urlto('ikiwiki/blue.monday/jplayer.blue.monday.css', $page). 
	'" type="text/css" rel="stylesheet">';
}

sub get_source {
    my $host = shift;
    my $browser = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => "$host/admin/stats.xml");
    $req->authorization_basic('administrador', '******');

    my $responce = $browser->request($req)->as_string;
    $host =~ s/^(.*)\:/$1/;

    my ($headers, $xml) = split(/\n{2,}/, $responce);
    if ($xml =~ m/localhost/) {
        $xml =~ s/localhost/$host/g;
    }
    my $parser = XML::LibXML->new();
    return $parser->parse_string($xml, {encoding => 'utf-8'});
}

sub parse_source
{
    my $source = $_[0];
    my @songs = ();
    my %seen = ();
    my $count = 0;
    foreach my $mount ($source->findnodes('/icestats/source')) {
        my($desc) = encode('utf-8', $mount->findnodes('./server_description')->to_literal);
        my($stream_name) = encode('utf-8', $mount->findnodes('./server_name')->to_literal);
        my($site_url) = encode('utf-8', $mount->findnodes('./server_url')->to_literal);
        my($song_title) = encode('utf-8', $mount->findnodes('./title')->to_literal);
        my($song_artist) = encode('utf-8', $mount->findnodes('./artist')->to_literal);
    my ($url) = $mount->findnodes('./listenurl')->to_literal;
    my %row_data;
    my @exts = qw(.oga .mp3);
    my ($id) = basename($url, @exts);
    if ( $url =~ /.og(g|a)/ ) {
	#use a mirror 
        my $mirror = 'r0';
	$url =~ s/^http:\/\/radio\.(flujos\.org):8000\/(.*)/http:\/\/$mirror.$1\/$2/g;
        $row_data{URL_OGG} = $url;
    }
    if ( $url =~ /.mp3/ ) {
	#use a mirror 
        my $mirror = 'r0';
	$url =~ s/^http:\/\/radio\.(flujos\.org):8000\/(.*)/http:\/\/$mirror.$1\/$2/g;
  	$row_data{URL_MP3} = $url;
    }
    $row_data{ID} = $id;
    $row_data{DESC} = $desc;
    $row_data{STREAM_NAME} = $stream_name;
    $row_data{SITE_URL} = $site_url;
    $row_data{SONG_TITLE} = $song_title;
    $row_data{SONG_ARTIST} = $song_artist;
    # averiguar ruta a cancion actual 
    if ($count % 2) {
        $row_data{ODDEVEN} = "odd";
    } else {
         $row_data{ODDEVEN} = "even";
    }
    $row_data{COUNT} = $count;
    if (!exists($seen{ $id})){
 	 push(@radios, \%row_data);
	 $seen{$id} = $id;
	 $count++;
    } else {
    foreach my $radio (@radios) {
        if ($radio->{ID} eq $id) {
            if ( $url =~ /.og(a|g)/ ) {
  	        $radio->{URL_OGG} = $url;
	        $radio->{SONG_TITLE} = $song_title;
		$radio->{SONG_ARTIST} = $song_artist;
  	        $radio->{DESC} = $desc;
    		$radio->{STREAM_NAME} = $stream_name;
            }
  	}
     if ( $url =~ /.mp3/ ) {
  	    $radio->{URL_MP3} = $url;
         }
      }
    }
    }
    #undef $song_title; 
    #return @radios;
}
1;
