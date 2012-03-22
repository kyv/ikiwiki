#!/usr/bin/perl
# Ikiwiki enhanced audio handling plugin
# kev@flujos.org
# Copiado de IkiWiki::Plugin::Img por:
# Christian Mock cm@tahina.priv.at 20061002

# uso: [!audio audios/cancion.oga class=left]

package IkiWiki::Plugin::audio;

use warnings;
use strict;
use IkiWiki 3.00;

use URI;

my $CONVERT = 'FALSE'; #change to true to auto transcode formats

my @savetags = ("artist", "title", "genre", "date");
my $urlogg = ""; 
my $urlmp3 = "";

# llamamos a los `hooks` de ikiwiki de procesamiento del plugin
sub import {
	# underlay = ficheros estaticos incluidos en el wiki
	add_underlay("360-player");
	# opicones de configuracion para el plugin 
	hook(type => "getsetup", id => "audio", call => \&getsetup);
	# la mayor parte de la logica del plugin, que devuelva salida de la plantilla
	hook(type => "preprocess", id => "audio", call => \&preprocess, scan => 1);
        # rutina que nos permita modificar toma la html saliendo de la platilla 
	hook(type => "format", id => "audio", call => \&format);
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
	my ($audio) = $_[0] =~ /$config{wiki_file_regexp}/; # untaint
	# paremetros de cgi
	my %params=@_;
	if (! defined $audio) {
		# devuelva error si no hay un audio	
		error("bad audio filename");
	}
	add_link($params{page}, $audio);
	add_depends($params{page}, $audio);
	# optimisacion: detectar modo escanear y no generar el audio 
	if (! defined wantarray) {
		return;
	}

	my $file = bestlink($params{page}, $audio); #obtener una ruta hacia el audio
	my $srcfile = srcfile($file, 1);
	my $dir = $params{page};
	my $base = IkiWiki::basename($file);
	my $audiolink = $file;
	my ($fileurl, $audiourl);
	if (! $params{preview}) {
		$fileurl=urlto($file, $params{destpage});
		$audiourl=urlto($audiolink, $params{destpage});
	}
	else {
		$fileurl="$config{url}/$file";
		$audiourl="$config{url}/$audiolink";
	}

 	# agregar el css 'class' `audio`
	if (exists $params{class}) {
		$params{class}.=" audio";
	}
	else {
		$params{class}="audio";
	}

	my $attrs='';
	foreach my $attr (qw{class id}) {
		if (exists $params{$attr}) {
			$attrs.=" $attr=\"$params{$attr}\"";
		}
	}
    my $template = template("audio.tmpl");
    $template->param(AUDIO_URL => $audio); # <audio src=""></audio>
    $template->param(class => $params{class}); # el usuario final puede difinir su proprio `class`	
    # consiguir las etiquetas de las audios
    # $template = get_tags($audio,$template);
    #devolver html 
    return $template->output;

}

sub checkurl (@) {

    use LWP::Simple qw($ua get);
    
    my $url = shift;
    my $net = $url;
    $net =~ s!^https?://(?:www\.)?!!i;
    $net =~ s!/.*!!;
    $ua->credentials( $net, "flujos" );
    $ua->timeout(10);
    $ua->max_size(1);
    my $r = $ua->get($url);
    if ($r->is_success) { 
    
       # ok document exists
       print "[audio] $url valido\n";
       return $url;
    } else {
       print "[audio] $url does not exist\n";
       return undef; 
    }
}

sub get_tags ($) {
    # obtener etiqutas del audio y agregarlos al html.
    my $file=shift;
    my $template=shift;
    my $TAGS;
    my @files;
    push(@files, $file);
    if (!-e $file) {
        if ($file =~ /http:\/\//){
            print "got a hold on $file\n";
	    #$TAGS = &get_metadata(\@files);
        } else {
                print  "Cant get a handle: $!\n";
                print  "Try abs path:\n";
                print "$ENV{HOME}/$config{srcdir}/$file\n";
                $file = "$ENV{HOME}/$config{srcdir}/$file";
	        #$TAGS = &get_metadata(\@files);
        }
    } else {
        print "got a hold on $file\n";
	#$TAGS = &get_metadata(\@files);
    }
    #my %data = %{$TAGS};
    #foreach  my $key ( keys %data) {
    #   if ($key && @{$data{$key}}) {
    #   print $key, ":", @{$data{$key}}, "\n";
    # 
    #   }else{
    #      print "[audio] metadata error:  $!"
    #   
    #   }
    #   $template->param($key => "@{$data{$key}}");
    #   foreach my $tag (@savetags) {
    #       if ( $template->param($tag) ) {
    #           $template->param(tags => "al huevo");
    #           # this should probaly set the tags instead of setting `al huevo` :)                 
    #        }
    #   }
    #}

    return $template;
}
sub format (@) {
    # parsea y modifica salida html de `preprocess`
    my %params=@_;
    # incluir el javascript
    $params{content}=include_javascript($params{page}, 1).$params{content};
    return $params{content};
}

sub include_javascript ($;$) {
    # javascript necesario para el funcionamiento del plugin
    my $page=shift;
    my $absolute=shift;

    return '<script src="'.urlto('ikiwiki/berniecode-animator.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
        '<script src="'.urlto('ikiwiki/soundmanager2.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
        '<script src="'.urlto('ikiwiki/360player.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
	'<!-- special IE-only canvas fix -->'. "\n" .
	'<!--[if IE]><script src="'urlto('ikiwiki/excanvas.js', $page). 
	'" type="text/javascript" charset="utf-8"></script><![endif]-->' . "\n" .
	'<link href="'.urlto('ikiwiki/360player.css', $page). 
	'" type="text/css" rel="stylesheet">'. "\n" .
	'<script type="text/javascript">'. "\n" .
	'    soundManager.url = '.urlto('ikiwiki/swf/', $page). ";\n".
	'    soundManager.useHTML5Audio = true;'. "\n".
  	'    soundManager.useConsole = true;'."\n".
	'    soundManager.preferFlash = false;'."\n".
   	'    soundManager.debugMode = true;'."\n".
	'</script>';

}

sub get_metadata {
   use Audio::Tagger qw(Any);
   my $ref = shift;
   my @audios = @{$ref};
   my %TAGS;
   for (@audios) {
	my $f = Any("$_"); 
	%TAGS = ( 
	   "ARTIST" , "$f->artist()",
           "TITLE" , "$f->title()",
           "ALBUM" , "$f->album()",
	);
    }
    return \%TAGS

}
   
sub print_tag {
     my ($list, $tag) = @_;
   
     foreach (@{$list -> { $tag }}) {
       if (defined $_) {
         printf "  %15s: %s\n", ucfirst $tag, $_;
       }
     }
}
1
