#!/usr/bin/perl
# Ikiwiki enhanced audio handling plugin
# kev@flujos.org
# Copiado de IkiWiki::Plugin::Img por:
# Christian Mock cm@tahina.priv.at 20061002

# uso: [!audio audios/cancion.oga class=float_left]

package IkiWiki::Plugin::audio;

use warnings;
use strict;
use IkiWiki 3.00;

my @savetags = ("artist", "title", "genre", "date");
my $urlogg = ""; 
my $urlmp3 = "";

# llamamos a los `hooks` de ikiwiki de procesamiento del plugin
sub import {
	# underlay = ficheros estaticos incluidos en el wiki
	add_underlay("javascript");
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
	# optimisation: detectar modo escanear y no generar el audio 
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
    $template->param(src => $audio); # <audio src=""></audio>
    $template->param(class => $params{class}); # el usuario final puede difinir su proprio `class`	
    # convertir entre ogg y un mp3
    #$template = convert($audio, $template); 
    # consiguir las etiquetas de las audios
    $template = get_tags($audio,$template);
    #devolver html 
    return $template->output;

}

sub convert (@) {
    # si existe un mp3, pero no existe ogg, genera el ogg
    # si existe un ogg, pero no existe mp3, genera el mp3
    # eso es necario para el desmadre de soporte de navigadores
    # utilizamos un script externo para hacer el trabajo duro
    my $file=shift;
    my $template=shift;
    my ($base, $in);
    if ($file =~ /http:\/\//) {
      # no convertir `streamings`
      ($base, $in) = $file =~ m{([^\\/.]+([^\\/]*)$)};
      #return $template;
    } else {
        ($base, $in) = split(/\./, $file);

    }
    my @sources = ($file);
        my $cmd;
        my $CONVERT;  
        if ($in =~ m/og(g|a)$/i) {
    	    if ($file =~ /http:\/\//) {
		$urlogg = $file;
  		$urlmp3 = $urlogg . ".mp3";
                my $absfile = "$urlogg";
	    } else {
	        $urlogg = "$base.$in";
	        $urlmp3 = $base . ".mp3";
                my $absfile = "$ENV{HOME}/$config{srcdir}/$urlmp3";
                if (!-e $absfile) {
                    print "$absfile doesnot exist\n";
                    $cmd = "gst-launch-0.10 filesrc location=$urlogg ! vorbisdec ! audioconvert ! lame ! id3mux !  filesink location=$urlmp3";
                }
	    }
	    $template->param(URL_OGG => "$urlogg");
            $template->param(type0 => "audio/ogg");
            $template->param(type1 => "audio/mpeg");
	    $template->param(URL_MP3 => "$urlmp3");
            $template->param(fallback => "$urlmp3");
            push(@sources, "$urlmp3");
        }
        
        if ($in =~ m/mp3$/i) {
	    $urlmp3 = "$base.$in";
            $template->param(type0 => "audio/mpeg");
            $template->param(type1 => "audio/ogg");
            $template->param(fallback => "$base.$in");
	    $template->param(URL_MP3 => "$base.$in");

            my $out = "oga"; 
	    $template->param(URL_OGG => "$base.$out");
	    $urlogg = "$base.$out";
            if (!-e "$ENV{HOME}/$config{srcdir}$base.$out") {
                $cmd = "gst-launch-0.10 filesrc location=$base.$in ! mad ! audioconvert ! vorbisenc ! oggmux !  filesink location=$base.$out" ;
                push(@sources, "$base.$out");
                }
        }
        # ejectutar orden de conversion
        if ($cmd) { 
            print "gst command: $cmd\n";
            system($cmd);
        }
       $template->param(src0 => $sources[0]);
       $template->param(src1 => $sources[1]);
    return $template;
}

sub get_tags ($) {
    # obtener etiqutas del audio y agregarlos al html.
    my $file=shift;
    my $template=shift;
    my $MD;
    my @files;
    push(@files, $file);
    if (!-e $file) {
        if ($file =~ /http:\/\//){
            print "got a hold on $file\n";
            #open(MD,"/usr/local/bin/read-metadata.pl $file|") || die "Failed http: $!\n";
	    $MD = &gst_metadata(\@files);
        } else {
                print  "Cant get a handle: $!\n";
                print  "Try abs path:\n";
                print "$ENV{HOME}/$config{srcdir}/$file\n";
                $file = "$ENV{HOME}/$config{srcdir}/$file";
                #open(MD,"/usr/local/bin/read-metadata.pl $file|") || die "Failed: $!\n";
	        $MD = &gst_metadata(\@files);
        }
    } else {
        print "got a hold on $file\n";
        #open(MD,"/usr/local/bin/read-metadata.pl $file|") || die "Failed: $!\n";
	$MD = &gst_metadata(\@files);
    }
    my %data = %{$MD};
    foreach  my $key ( keys %data) {
       if ($key && @{$data{$key}}) {
       print $key, ":", @{$data{$key}}, "\n";
     
       }else{
          print "[audio] metadata error:  $!"
       
       }
       $template->param($key => @{$data{$key}});
       foreach my $tag (@savetags) {
           if ( $template->param($tag) ) {
               $template->param(tags => "al huevo");
	       # this should probaly set the tags instead of setting `al huevo` :)                 
            }
       }
    }

    return $template;
}

sub format (@) {
    # parsea y modifica salida html de `preprocess`
    my %params=@_;
    my $string=&include_player; # rutina que formatea el `player`
    # $params{content} contiene el html como producido por la platilla arriba
    # buscamos el un div de `audio` y agregamos el reproductor dentro del div
    $params{content}=~s/(<div class="audio">)/$1$string/;
    # incluir el javascript
    $params{content}=include_javascript($params{page}, 1).$params{content};
    return $params{content};
}

sub include_player {
    # nuestra reproductor de audio
my $string = <<STRING;
  
<script type="text/javascript">
 \$(document).ready(function(){
   \$("#jquery_jplayer").jPlayer({
     ready: function () {
       \$(this).jPlayer("setMedia", {
         mp3: "$urlmp3",
         oga: "$urlogg"
       });
     },
     swfPath: "/jplayer",
     supplied: "mp3, oga",
     cssSelectorAncestor: "#jp_interface" 
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

    return '<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.4/jquery.min.js"'.
        '" type="text/javascript" charset="utf-8"></script>'."\n".
        '<script src="'.urlto('ikiwiki/jquery.jplayer.min.js', $page).
        '" type="text/javascript" charset="utf-8"></script>'. "\n" .
	'<link href="'.urlto('jplayer/jplayer.blue.monday.css', $page). 
	'" type="text/css" rel="stylesheet">';
}

sub gst_metadata {
# This is a Perl port of an example found in the gstreamer-0.9.6 tarball.
# Original and current copyright:
# GStreamer
# Copyright (C) 2003 Thomas Vander Stichele <thomas@apestaart.org>
#               2003 Benjamin Otte <in7y118@public.uni-hamburg.de>
#               2005 Andy Wingo <wingo@pobox.com>
#               2005 Jan Schmidt <thaytan@mad.scientist.com>
# gst-metadata.c: Use GStreamer to display metadata within files.

   use Glib qw(TRUE FALSE);
   use GStreamer qw(GST_MSECOND);
   my $ref = shift;
   my @list = @{$ref};
   my ($filename, $pipeline, $source, $tags);
   
   GStreamer -> init();
   
   if ($#list < 0) {
     print "Please give filenames to read metadata from\n";
     exit 1;
   }
   
   foreach (@list) {
     print "element of list: $_\n";
     if (m/http:\/\//){
         ($pipeline, $source) = make_pipeline("http", $pipeline, $source);
     } else {
         ($pipeline, $source) = make_pipeline("file", $pipeline, $source);
     }
     $filename = $_;
     $source -> set(location => Glib::filename_to_unicode $filename);
      
     # Decodebin will only commit to PAUSED if it actually finds a type;
     # otherwise the state change fails
     my $sret = $pipeline -> set_state("paused");
   
     if ("async" eq $sret) {
       ($sret, undef, undef) = $pipeline -> get_state(5000 * GST_MSECOND);
     }
   
     if ("success" ne $sret) {
       printf "%s - Could not read file\n", $filename;
       next;
     }
   
     $tags = message_loop($pipeline);
   
     unless (defined $tags) {
       printf "No metadata found for %s\n", Glib::filename_display_name $_;
     }
     #map { print_tag($tags, $_) } keys %$tags; #test tags
   
     $pipeline -> set_state("null");
   }
   return $tags;
}
sub message_loop {
     my ($element) = @_;
   
     my $tags = {};
     my $done = FALSE;
   
     my $bus = $element -> get_bus();
   
     return undef unless defined $bus;
     return undef unless defined $tags;
   
     while (!$done) {
       my $message = $bus -> poll("any", 0);
       unless (defined $message) {
         # All messages read, we're done
         last;
       }
   
       if ($message -> type & "eos") {
         # End of stream, no tags found yet -> return undef
         return undef;
       }
       if ($message -> type & "error") {
         # decodebin complains about not having an element attached to its output.
         # Sometimes this happens even before the "tag" message, so just continue.
         next;
       }
       elsif ($message -> type & "tag") {
         my $new_tags = $message -> tag_list();
         foreach (keys %$new_tags) {
           unless (exists $tags -> { $_ }) {
             $tags -> { $_ } = $new_tags -> { $_ };
           }
         }
       }
     }
   
     return $tags;
}
   
sub make_pipeline {
     my $decodebin;
     my $f_source = shift;
     my $pipeline = shift; 
     my $source = shift; 
     $pipeline = GStreamer::Pipeline -> new(undef);
     
     if ($f_source eq "http") {
     ($source, $decodebin) =
       GStreamer::ElementFactory -> make(souphttpsrc => "source",
                                         decodebin => "decodebin");
     } else {
     ($source, $decodebin) =
       GStreamer::ElementFactory -> make(filesrc => "source",
                                         decodebin => "decodebin");
       
     }
   
     $pipeline -> add($source, $decodebin);
     $source -> link($decodebin);
     return $pipeline, $source; 
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
