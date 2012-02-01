#!/usr/bin/perl
# Ikiwiki playlist handling plugin
# kev@flujos.org

# uso: [!playlist playlists/shostakovich.m3u class=float_left]

package IkiWiki::Plugin::playlist;

use warnings;
use strict;
use IkiWiki 3.00;

my $formated_pls;

# llamamos a los `hooks` de ikiwiki de procesamiento del plugin
sub import {
	# underlay = ficheros estaticos incluidos en el wiki
	add_underlay("javascript");
	# opicones de configuracion para el plugin 
	hook(type => "getsetup", id => "playlist", call => \&getsetup);
	# la mayor parte de la logica del plugin, que devuelva salida de la plantilla
	hook(type => "preprocess", id => "playlist", call => \&preprocess, scan => 1);
        # rutina que nos permita modificar toma la html saliendo de la platilla 
	hook(type => "format", id => "playlist", call => \&format);
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
	my ($pls) = $_[0] =~ /$config{wiki_file_regexp}/; # untaint
	# paremetros de cgi
	my %params=@_;
	if (! defined $pls) {
		# devuelva error si no hay un audio	
		error("[playlist] fichero erroneo");
	}
	add_link($params{page}, $pls);
	add_depends($params{page}, $pls);
	# optimisacion: detectar modo escanear y no generar el playlist 
	if (! defined wantarray) {
		return;
	}

	#obtener una ruta hacia el audio
	my $file = bestlink($params{page}, $pls); 
	my $srcfile = srcfile($file, 1);
	my $dir = $params{page};
	my $base = IkiWiki::basename($file);
	my $plslink = $file;
	my ($fileurl, $plsurl);
	if (! $params{preview}) {
		$fileurl=urlto($file, $params{destpage});
		$plsurl=urlto($plslink, $params{destpage});
	}
	else {
		$fileurl="$config{url}/$file";
		$plsurl="$config{url}/$plslink";
	}

 	# agregar el css 'class' `playlist`
	if (exists $params{class}) {
		$params{class}.=" playlist";
	}
	else {
		$params{class}="playlist";
	}

	my $attrs='';
	foreach my $attr (qw{class id}) {
		if (exists $params{$attr}) {
			$attrs.=" $attr=\"$params{$attr}\"";
		}
	}
    my $template = template("playlist.tmpl");
    $template->param(src => $pls); 
    # el usuario final puede difinir su proprio `class`	
    $template->param(class => $params{class});
    $formated_pls = &get_static_pls($pls);
    #my @showtimes = &cron_find($playlist);
    $template->param(PLAYLIST=>$pls);
    #$template->param(PLAYLIST_ITEMS => \@playlist_items);

    #$template->param(SHOWTIMES=> \@showtimes);
    $template->param(SONG_TITLE=> $params{title});
    $template->param(SONG_ARTIST=> $params{artist});
    return $template->output;

}

sub format (@) {
    # parsea y modifica salida html de `preprocess`
    my %params=@_;
    # rutina que formatea el `player`
    my $string=&include_player; 
    # $params{content} contiene el html como producido por la platilla arriba
    # buscamos el un div de `audio` y agregamos el reproductor dentro del div
    $params{content}=~s/(<div class="playlist">)/$1$string/; #todo: account for case of multiple `class`
    # incluir el javascript
    $params{content}=include_javascript($params{page}, 1).$params{content};
    return $params{content};
}

sub include_player {
    # nuestra reproductor de audio
my $player = <<PLAYER;

<script type="text/javascript">
\$(document).ready(function(){
		var Playlist = function(instance, playlist, options) {
		var self = this;

		this.instance = instance; // String: To associate specific HTML with this playlist
		this.playlist = playlist; // Array of Objects: The playlist
		this.options = options; // Object: The jPlayer constructor options for this playlist

		this.current = 0;

		this.cssId = {
			jPlayer: "jquery_jplayer_",
			interface: "jp_interface_",
			playlist: "jp_playlist_"
		};
		this.cssSelector = {};
		\$.each(this.cssId, function(entity, id) {
			self.cssSelector[entity] = "#" + id + self.instance;
		});

		if(!this.options.cssSelectorAncestor) {
			this.options.cssSelectorAncestor = this.cssSelector.interface;
		}

		\$(this.cssSelector.jPlayer).jPlayer(this.options);

		\$(this.cssSelector.interface + " .jp-previous").click(function() {
			self.playlistPrev();
			\$(this).blur();
			return false;
		});

		\$(this.cssSelector.interface + " .jp-next").click(function() {
			self.playlistNext();
			\$(this).blur();
			return false;
		});
	};

	Playlist.prototype = {
		displayPlaylist: function() {
			var self = this;
			\$(this.cssSelector.playlist + " ul").empty();
			for (i=0; i < this.playlist.length; i++) {
				var listItem = (i === this.playlist.length-1) ? "<li class='jp-playlist-last'>" : "<li>";
				listItem += "<a href='#' id='" + this.cssId.playlist + this.instance + "_item_" + i +"' tabindex='1'>"+ this.playlist[i].name +"</a>";

				// Create links to free media
				if(this.playlist[i].free) {
					var first = true;
					listItem += "<div class='jp-free-media'>(";
					\$.each(this.playlist[i], function(property,value) {
						if(\$.jPlayer.prototype.format[property]) { // Check property is a media format.
							if(first) {
								first = false;
							} else {
								listItem += " | ";
							}
							listItem += "<a id='" + self.cssId.playlist + self.instance + "_item_" + i + "_" + property + "' href='" + value + "' tabindex='1'>" + property + "</a>";
						}
					});
					listItem += ")</span>";
				}

				listItem += "</li>";

				// Associate playlist items with their media
				\$(this.cssSelector.playlist + " ul").append(listItem);
				\$(this.cssSelector.playlist + "_item_" + i).data("index", i).click(function() {
					var index = \$(this).data("index");
					if(self.current !== index) {
						self.playlistChange(index);
					} else {
						\$(self.cssSelector.jPlayer).jPlayer("play");
					}
					\$(this).blur();
					return false;
				});

				// Disable free media links to force access via right click
				if(this.playlist[i].free) {
					\$.each(this.playlist[i], function(property,value) {
						if(\$.jPlayer.prototype.format[property]) { // Check property is a media format.
							\$(self.cssSelector.playlist + "_item_" + i + "_" + property).data("index", i).click(function() {
								var index = \$(this).data("index");
								\$(self.cssSelector.playlist + "_item_" + index).click();
								\$(this).blur();
								return false;
							});
						}
					});
				}
			}
		},
		playlistInit: function(autoplay) {
			if(autoplay) {
				this.playlistChange(this.current);
			} else {
				this.playlistConfig(this.current);
			}
		},
		playlistConfig: function(index) {
			\$(this.cssSelector.playlist + "_item_" + this.current).removeClass("jp-playlist-current").parent().removeClass("jp-playlist-current");
			\$(this.cssSelector.playlist + "_item_" + index).addClass("jp-playlist-current").parent().addClass("jp-playlist-current");
			this.current = index;
			\$(this.cssSelector.jPlayer).jPlayer("setMedia", this.playlist[this.current]);
		},
		playlistChange: function(index) {
			this.playlistConfig(index);
			\$(this.cssSelector.jPlayer).jPlayer("play");
		},
		playlistNext: function() {
			var index = (this.current + 1 < this.playlist.length) ? this.current + 1 : 0;
			this.playlistChange(index);
		},
		playlistPrev: function() {
			var index = (this.current - 1 >= 0) ? this.current - 1 : this.playlist.length - 1;
			this.playlistChange(index);
		}
	};
	var audioPlaylist = new Playlist("1", [
	$formated_pls
	], {
		ready: function() {
			audioPlaylist.displayPlaylist();
			audioPlaylist.playlistInit(false); // Parameter is a boolean for autoplay.
		},
		ended: function() {
			audioPlaylist.playlistNext();
		},
		play: function() {
			\$(this).jPlayer("pauseOthers");
		},
		swfPath: "js",
		supplied: "oga, mp3",
		preload: "none"

	});
});
</script>

PLAYER
return $player; 
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
sub get_static_pls {  
    use File::Basename;
    my $pls = shift;
    my @playlist_items;
        open(PLS, "<$pls") || die "Failed: $!\n";
        LINE: for (<PLS>) 
        {
	    # unicamente manejamos ogg y mp3
	    next LINE unless /\.(og(g|a)|mp3)/i;
	    my %playlist;
	    $_ =~ s/\s+$//;
	    my $base = basename($_); 
    	    #$base =~ s/(.*)\.(mp3|og(a|g))/$1/; turn on later
	    $playlist{name} = $base;
            $playlist{free} = 'true';
            if ( $_ =~ /\.og(g|a)/i ) {
	        $playlist{oga} = $_;
	    }
            if ( $_ =~ /\.mp3/i ) {
	        $playlist{mp3} = $_;
	    }   
	    push(@playlist_items, \%playlist);
        }
	my $string;
        foreach my $song (@playlist_items) {
            $string = $string . "{\n";
            foreach my $key (keys %$song) {
                $string = $string.$key.': '."\""."$song->{$key}"."\"".",\n";
                }
            $string = $string . "},\n";
        }
	return $string;
}    

sub get_mpd_current_pls {
    my @playlist_items;
	my $mpd = Audio::MPD->new;
        my @items = $mpd->playlist->as_items;
	for (@items) 
	{
	    my %playlist_item;
            my $str = encode('utf-8', $_->as_string); 
	    #$_ =~ s/\s+$//;
	    $playlist_item{ITEM_NAME} = "$str";
		my $file = encode('utf-8', $_->file); 
	        #$playlist_item{ITEM_NAME} = "$base";
                if ( $file =~ /\.og(g|a)/i ) {
	           unless ($_ =~ /http\:\/\//){$playlist_item{URL_OGG} = "audio/$file";}
		}
                if ( $file =~ /\.mp3/i ) {
	            unless ($_ =~ /http\:\/\//){$playlist_item{URL_MP3} = "audio/$file";}
	       }

    push(@playlist_items, \%playlist_item);
	}
    return @playlist_items;  
}
1
