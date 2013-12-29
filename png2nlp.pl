#!/usr/local/bin/Perl
=begin

Copyright (c) 2013 Michael Hawthorne (Jigglebizz)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

use strict;
use warnings;

use GD;
use MIDI;
use Getopt::Long;

main();

sub main {
    my $iFile = "image.bmp";
    my $oFile = "midi.mid";
    my $qnt   = 96;
    
    GetOptions( "i=s" => \$iFile,
                "o=s" => \$oFile );
    
    my $img = GD::Image->new($iFile) or die "Could not open " . $iFile;
    my ($width, $height) = $img->getBounds();
    
    my @midi_events = ();
    
    # In case there is no change between frames
    # This must be used to set correct timing of MIDI events
    my $frames_multiplier = 1;
    
    # Traverse the frames
    for (my $i = 0; $i < $width / 8; $i++) {
        my $frame = GD::Image->new(8, 8);
        $frame->copy($img, 0, 0, $i * 8, 0, 8, 8);
        
        # Get our previous and next frames
        #
        # This allows us to sustain consistent colors
        # And prevent flickering.
        my ($prev_frame, $next_frame);
        if ($i != 0) {
            $prev_frame = GD::Image->new(8, 8);
            $prev_frame->copy($img, 0, 0, ($i - 1) * 8, 0, 8, 8);
        }
        if ($i != ($width / 8) - 1) {
            $next_frame = GD::Image->new(8, 8);
            $next_frame->copy($img, 0, 0, ($i + 1) * 8, 0, 8, 8);
        }
        
        #MIDI Event:
        #   note_on  dtime channel note velocity
        #   note_off dtime channel note velocity
        
        # Traverse pixels, place note_ons
        my %prev_velocities = ();
        for (my $y = 0; $y < 8; $y++) {
            for (my $x = 0; $x < 8; $x++) {
                my $color_index = $frame->getPixel($x, 7 - $y);
                my ($r, $g, $b) = $frame->rgb($color_index);
                my $midi_velocity = convertColorToLight($r, $g, $b);
                
                my $prev_velocity;
                if (defined $prev_frame) {
                    my $prev_index        = $prev_frame->getPixel($x, 7 - $y);
                    my ($p_r, $p_g, $p_b) = $prev_frame->rgb($prev_index);
                    $prev_velocity = convertColorToLight($p_r, $p_g, $p_b);
                }
                
                my $midi_note = 36 + (($x<4)? $x+($y*4) : 32+($x-4)+($y*4));
                
                if (not defined $prev_velocity or $prev_velocity != $midi_velocity) {
                    push @midi_events,
                        ['note_on', 0, 0, $midi_note, $midi_velocity];
                }
            }
        }
        
        my $is_offset = 0;
        for (my $y = 0; $y < 8; $y++) {
            for (my $x = 0; $x < 8; $x++) {
                my $color_index = $frame->getPixel($x, 7 - $y);
                my ($r, $g, $b) = $frame->rgb($color_index);
                my $midi_velocity = convertColorToLight($r, $g, $b);
                
                my $next_velocity;
                if (defined $next_frame) {
                    my $next_index        = $next_frame->getPixel($x, 7 - $y);
                    my ($n_r, $n_g, $n_b) = $next_frame->rgb($next_index);
                    $next_velocity = convertColorToLight($n_r, $n_g, $n_b);
                }
                
                my $midi_note = 36 + (($x<4)? $x+($y*4) : 32+($x-4)+($y*4));
                
                if (not defined $next_velocity or $next_velocity != $midi_velocity) {
                    unless ($is_offset) {
                        push @midi_events,
                            ['note_off', $qnt * $frames_multiplier, 0, $midi_note, $midi_velocity];
                        $is_offset = 1;
                        $frames_multiplier = 1;
                    }
                    else {
                        push @midi_events,
                            ['note_off', 0, 0, $midi_note, $midi_velocity];
                    }
                }
            }
        }
        unless ($is_offset) {
            $frames_multiplier++;
        }
    }
    
    # Write MIDI Events to file
    my $midi_track = MIDI::Track->new({ 'events' => \@midi_events });
    my $opus = MIDI::Opus->new(
        { 'format' => 0, 'ticks' => $qnt, 'tracks' => [$midi_track]});
    $opus->write_to_file( $oFile );
}

sub convertColorToLight {
    my ($r, $g, $b) = @_;
    
    # Convert r and g to their 2-bit equivalents
    my $r_2b = $r / 64;
    my $g_2b = $g / 64;
    
    # Formula from Launchpad manual. red + 16 * green + flags
    my $v = $r_2b + (16 * $g_2b);
    return $v;
}
