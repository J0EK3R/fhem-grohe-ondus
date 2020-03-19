###############################################################################
#
# Developed with eclipse
#
#  (c) 2019 Copyright: J.K. (J0EK3R at gmx dot net)
#  All rights reserved
#
#  The GroheOndus modules are based on 73_GardenaSmartBridge.pm and 
#  74_GardenaSmartDevice from Marko Oldenburg (leongaultier at gmail dot com)
#
#   Special thanks goes to comitters:
#  
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id: 74_GroheOndusSmartDevice.pm 19641 2019-06-18 14:47:13Z CoolTux $
#
###############################################################################
##
##
## Das JSON Modul immer in einem eval aufrufen
# $data = eval{decode_json($data)};
#
# if($@){
#   Log3($SELF, 2, "$TYPE ($SELF) - error while request: $@");
#
#   readingsSingleUpdate($hash, "state", "error", 1);
#
#   return;
# }
#
#
###### Wichtige Notizen
#
#   apt-get install libio-socket-ssl-perl
#   http://www.dxsdata.com/de/2016/07/php-class-for-gardena-smart-system-api/
#
##
##

## unserer packagename
package FHEM::GroheOndusSmartDevice;

use GPUtils qw(GP_Import);    # wird für den Import der FHEM Funktionen aus der fhem.pl benÃ¶tigt

my $missingModul = "";

use strict;
use warnings;
use POSIX;
use FHEM::Meta;
use Time::Local;
use Time::HiRes qw(gettimeofday);
our $VERSION = '2.0.0';

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval 
{
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
};

if ($@) 
{
    $@ = undef;

    # try to use JSON wrapper
    #   for chance of better performance
    eval 
    {
        # JSON preference order
        local $ENV{PERL_JSON_BACKEND} = 'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
          unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

        require JSON;
        import JSON qw( decode_json encode_json );
        1;
    };

    if ($@) 
    {
        $@ = undef;

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval 
        {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        };

        if ($@) 
        {
            $@ = undef;

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval 
            {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            };

            if ($@) 
            {
                $@ = undef;

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval 
                {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                };

                if ($@) 
                {
                    $@ = undef;

                    # Fallback to JSON::backportPP in really rare cases
                    require JSON::backportPP;
                    import JSON::backportPP qw(decode_json encode_json);
                    1;
                }
            }
        }
    }
}

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN 
{
    # Import from main context
    GP_Import(
        qw(readingsSingleUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsBeginUpdate
          readingsEndUpdate
          Log3
          CommandAttr
          AttrVal
          ReadingsVal
          readingFnAttributes
          AssignIoPort
          modules
          IOWrite
          defs
          RemoveInternalTimer
          InternalTimer
          init_done
          IsDisabled
          deviceEvents
          gettimeofday
          makeDeviceName)
    );
}

#####################################
# _Export - Export references to main context using a different naming schema
sub _Export 
{
    no strict qw/refs/;    ## no critic
    my $pkg  = caller(0);
    my $main = $pkg;
    $main =~ s/^(?:.+::)?([^:]+)$/main::$1\_/g;
    foreach (@_) 
    {
        *{ $main . $_ } = *{ $pkg . '::' . $_ };
    }
}

#####################################
#-- Export to main context with different name
_Export(
    qw(
      Initialize
      )
);

#####################################
sub Initialize($) 
{
    my ($hash) = @_;

    # Provider
    $hash->{Match} = '^{"appliance_id":".*';

    # Consumer
    $hash->{SetFn}   = "FHEM::GroheOndusSmartDevice::Set";
    $hash->{DefFn}   = "FHEM::GroheOndusSmartDevice::Define";
    $hash->{UndefFn} = "FHEM::GroheOndusSmartDevice::Undef";
    $hash->{DeleteFn} = "FHEM::GroheOndusSmartDevice::Delete";
    $hash->{ParseFn} = "FHEM::GroheOndusSmartDevice::Parse";
    $hash->{NotifyFn} = "FHEM::GroheOndusSmartDevice::Notify";

    $hash->{AttrFn} = "FHEM::GroheOndusSmartDevice::Attr";
    $hash->{AttrList} = ""
      . "model:sense,sense_guard "
      . "IODev "
      . "disable:1 "
      . "interval "
      . 'disabledForIntervals '
      . $readingFnAttributes;

    foreach my $d ( sort keys %{ $modules{GroheOndusSmartDevice}{defptr} } ) 
    {
    	my $hash = $modules{GroheOndusSmartDevice}{defptr}{$d};
    	$hash->{VERSION} = $VERSION;
    }

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

#####################################
# Define( $hash, $def)
sub Define($$) 
{
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t]+", $def );

    return $@ 
      unless ( FHEM::Meta::SetInternals($hash) );
   
    return "too few parameters: define <NAME> GroheOndusSmartDevice <device_Id> <model>"
      if ( @a < 3 );

    return "Cannot define GroheOndus Bridge device. Perl modul $missingModul is missing."
      if ($missingModul);

    my $name     = $a[0];
    my $deviceId = $a[2];
    my $model = $a[3];

    $hash->{DEVICEID}                = $deviceId;
    $hash->{VERSION}                 = $VERSION;
    $hash->{NOTIFYDEV} = "global,$name";
    $hash->{WATERCONSUMPTIONOFFSET} = 0;

	# set model depending defaults
    ### sense_guard
    if ( $model eq 'sense_guard' )
   	{
    	# the SenseGuard devices update every 15 minutes
 	   $hash->{INTERVAL}  = 60;
	}
	### sense
	elsif ( $model eq 'sense' )
    {
    	# the Sense devices update just once a day
    	$hash->{INTERVAL}  = 600;
    }

    CommandAttr( undef, "$name IODev $modules{GroheOndusSmartBridge}{defptr}{BRIDGE}->{NAME}" )
      if ( AttrVal( $name, 'IODev', 'none' ) eq 'none' );

    my $iodev = AttrVal( $name, 'IODev', 'none' );

    AssignIoPort( $hash, $iodev ) 
      if ( !$hash->{IODev} );

    if ( defined( $hash->{IODev}->{NAME} ) ) 
    {
        Log3 $name, 3, "GroheOndusSmartDevice ($name) - I/O device is " . $hash->{IODev}->{NAME};
    }
    else 
    {
        Log3 $name, 1, "GroheOndusSmartDevice ($name) - no I/O device";
    }

    $iodev = $hash->{IODev}->{NAME};

    my $d = $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

    return "GroheOndusSmartDevice device $name on GroheOndusSmartBridge $iodev already defined."
      if (  defined($d)
        and $d->{IODev} == $hash->{IODev}
        and $d->{NAME} ne $name );

    # ensure attribute room is present
    CommandAttr( undef, $name . ' room GroheOndusSmart' )
      if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

    # ensure attribute model is present
    CommandAttr( undef, $name . ' model ' . $model )
      if ( AttrVal( $name, 'model', 'none' ) eq 'none' );

    # ensure attribute inerval is present
    CommandAttr( undef, $name . ' interval ' . $hash->{INTERVAL} )
      if ( AttrVal( $name, 'interval', 'none' ) eq 'none' );

    Log3 $name, 3, "GroheOndusSmartDevice ($name) - defined GroheOndusSmartDevice with DEVICEID: $deviceId";

    readingsSingleUpdate( $hash, 'state', 'initialized', 1 );

    $modules{GroheOndusSmartDevice}{defptr}{$deviceId} = $hash;

    return undef;
}

#####################################
# Undef( $hash, $arg )
sub Undef($$) 
{
    my ( $hash, $arg ) = @_;
    my $name     = $hash->{NAME};
    my $deviceId = $hash->{DEVICEID};

    RemoveInternalTimer($hash);

    delete $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

    return undef;
}

#####################################
# Delete( $hash, $name )
sub Delete($$) 
{
    my ( $hash, $name ) = @_;

    return undef;
}

#####################################
sub Attr(@) 
{
    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};

    Log3 $name, 4, "GroheOndusSmartDevice ($name) - Attr was called";

	# Attribute "disable"
    if ( $attrName eq 'disable' ) 
    {
        if ( $cmd eq 'set' and $attrVal eq '1' ) 
        {
            RemoveInternalTimer($hash);
            readingsSingleUpdate( $hash, 'state', 'inactive', 1 );
            Log3 $name, 3, "GroheOndusSmartDevice ($name) - disabled";
        }
        elsif ( $cmd eq 'del' ) 
        {
            readingsSingleUpdate( $hash, 'state', 'active', 1 );
            Log3 $name, 3, "GroheOndusSmartDevice ($name) - enabled";
        }
    }
	# Attribute "disabledForIntervals"
    elsif ( $attrName eq 'disabledForIntervals' ) 
    {
        if ( $cmd eq 'set' ) 
        {
            return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
              unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );
    
            Log3 $name, 3, "GroheOndusSmartDevice ($name) - disabledForIntervals";
        }
        elsif ( $cmd eq 'del' ) 
        {
            readingsSingleUpdate( $hash, 'state', 'active', 1 );
            Log3 $name, 3, "GroheOndusSmartDevice ($name) - enabled";
        }
    }
	# Attribute "interval"
    elsif ( $attrName eq 'interval' ) 
    {
		# onchange event for attribute "interval" is handled in sub "Notify" -> calls "updateValues" -> Timer is reloaded
        if ( $cmd eq 'set' ) 
        {
            return 'Interval must be greater than 0'
              unless ( $attrVal > 0 );
          
            RemoveInternalTimer($hash);
            $hash->{INTERVAL} = $attrVal;

            Log3 $name, 3, "GroheOndusSmartDevice ($name) - set interval: $attrVal";
        }
        elsif ( $cmd eq 'del' ) 
        {
            RemoveInternalTimer($hash);
            $hash->{INTERVAL} = 60;

            Log3 $name, 3, "GroheOndusSmartDevice ($name) - delete User interval and set default: 60";
        }
    }
	# Attribute "waterconsumptionoffset"
    elsif ( $attrName eq 'waterconsumptionoffset' ) 
    {
        if ( $cmd eq 'set' ) 
        {
            $hash->{WATERCONSUMPTIONOFFSET} = $attrVal;

            Log3 $name, 3, "GroheOndusSmartDevice ($name) - set waterconsumptionoffset: $attrVal";
        }
        elsif ( $cmd eq 'del' ) 
        {
            $hash->{WATERCONSUMPTIONOFFSET} = 0;

            Log3 $name, 3, "GroheOndusSmartDevice ($name) - delete User waterconsumptionoffset and set default: 0";
        }
    }    
    return undef;
}

#####################################
sub Notify($$) 
{
    my ( $hash, $dev ) = @_;
    my $name = $hash->{NAME};
    
    return 
      if ( IsDisabled($name) );

    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = deviceEvents( $dev, 1 );

    return 
      if ( !$events );

    Log3 $name, 4, "GroheOndusSmartDevice ($name) - Notify";

	# process 'global' events
    if (
      $devtype eq 'Global'
      and (
          grep /^DELETEATTR.$name.disable$/, @{$events} 
          or grep /^ATTR.$name.disable.0$/, @{$events} 
          or grep /^DELETEATTR.$name.interval$/, @{$events} 
          or grep /^ATTR.$name.interval.[0-9]+/, @{$events}
      )
      and $init_done
    )
	{
	    updateValues($hash)
	}
	
	# process internal events
    if (
      $devtype eq 'GroheOndusSmartDevice'
      and (
            grep /^state:.connected.to.cloud$/, @{$events}
        )
      )
    {
    	# initial load of the timer on state changed to "connected to cloud"
    	# after 2 seconds 
      	InternalTimer( gettimeofday() + 2, "FHEM::GroheOndusSmartDevice::updateValues", $hash );
    }

    return;
}

#####################################
sub Set($@) 
{
    my ( $hash, $name, $cmd, @args ) = @_;

    my $payload;
    my $model = AttrVal( $name, 'model', 'unknown' );
    my $modelId;
    my $deviceId = $hash->{DEVICEID};

    Log3 $name, 4, "GroheOndusSmartDevice ($name) - Set was called: cmd= $cmd";

	#########################################################
    ### sense_guard #########################################
	#########################################################
    if ( $model eq 'sense_guard' )
   	{
	  	$modelId = 103;
	
	    ### Command 'refreshvalues'
	   	if ( lc $cmd eq 'refreshvalues' ) 
    	{
    		my $offsetLocalTimeGMT_hours = getGMTOffset();
    		my $requestFromTimestamp = getGMTMidnightDate();

	   		$hash->{helper}{offsetLocalTimeGMTime} = $offsetLocalTimeGMT_hours;
			$hash->{helper}{lastrequestfromtimestamp} = $requestFromTimestamp;
    
			# playload
	 		$payload =
   			{
 				'method' => 'GET',
  		  		'URI' => '/data?from=' . $requestFromTimestamp,
	 			'payload' => ""
			};
  	  	}
    	### Command 'refreshstate'
   		elsif ( lc $cmd eq 'refreshstate' ) 
   	 	{
			# playload
    		$payload =
    		{
    			'method' => 'GET',
    			'URI' => '/status',
    			'payload' => ""
			};
	    }
    	### Command 'getApplianceCommand'
   		elsif ( lc $cmd eq 'getappliancecommand' ) 
    	{
			# playload
    		$payload =
    		{
    			'method' => 'Get',
    			'URI' => '/command',
    			'payload' => ""
			};
	    }
    	### Command 'on'
    	elsif ( lc $cmd eq 'on' ) 
		{
    		my $command =  
	        {
   		    	'appliance_id' => $deviceId,
       			'type' => $modelId,
       			'command' => 
				{
    		#	  'measure_now' => $measure_now,
   	    	#	  'buzzer_on' => $buzzer_on,
   		  	#	  'buzzer_sound_profile' => $buzzer_sound_profile,
	    	  	  'valve_open' => 1 #$valve_open,
   		    #	  'temp_user_unlock_on' => $temp_user_unlock_on
				}
	        };

			# playload
    		$payload =
    		{
    			'method' => 'POST',
    			'URI' => '/command',
    			'payload' => encode_json( $command )
			};
	    }
    	### Command 'off'
    	elsif ( lc $cmd eq 'off' ) 
    	{
    		my $command =  
	        {
   		    	'appliance_id' => $deviceId,
       			'type' => $modelId,
       			'command' => 
				{
    		#	  'measure_now' => $measure_now,
   	    	#	  'buzzer_on' => $buzzer_on,
   		  	#	  'buzzer_sound_profile' => $buzzer_sound_profile,
	    	  	  'valve_open' => 0 #$valve_open,
   		    #	  'temp_user_unlock_on' => $temp_user_unlock_on
				}
	        };

			# playload
    		$payload =
    		{
    			'method' => 'POST',
    			'URI' => '/command',
    			'payload' => encode_json( $command )
			};
	    }
    	### Command 'buzzer'
    	elsif ( lc $cmd eq 'buzzer' ) 
    	{
    		# parameter is "on" or "off" so convert to "true" : "false"
    		my $onoff = join( " ", @args ) eq "on" ? "true" : "false";
    		
			Log3 $name, 5, "GroheOndusSmartDevice ($name) - command buzzer: $onoff";

    		my $command =  
	        {
   		    	'appliance_id' => $deviceId,
       			'type' => $modelId,
       			'command' => 
				{
    		#	  'measure_now' => $measure_now,
   	    		  'buzzer_on' => $onoff #$buzzer_on,
   		  	#	  'buzzer_sound_profile' => $buzzer_sound_profile,
	    	#  	  'valve_open' => $valve_open,
   		    #	  'temp_user_unlock_on' => $temp_user_unlock_on
				}
	        };

			# playload
    		$payload =
    		{
    			'method' => 'POST',
    			'URI' => '/command',
    			'payload' => encode_json( $command )
			};
	  	}
  	    ### unknown Command
    	else 
	    {
    	    my $list = 'on:noArg off:noArg refreshValues:noArg refreshState:noArg getApplianceCommand:noArg buzzer:on,off';

	        return "Unknown argument $cmd, choose one of $list";
    	}
    }
	#########################################################
	### sense ###############################################
	#########################################################
	elsif ( $model eq 'sense' )
    {
 		$modelId = 100;

	    ### Command 'refreshvalues'
	   	if ( lc $cmd eq 'refreshvalues' ) 
	    {
    		my $offsetLocalTimeGMT_hours = getGMTOffset();
    		my $requestFromTimestamp = getGMTMidnightDate();

   			$hash->{helper}{offsetLocalTimeGMTime} = $offsetLocalTimeGMT_hours;
			$hash->{helper}{lastrequestfromtimestamp} = $requestFromTimestamp;
    
			# playload
	 		$payload =
   			{
   				'method' => 'Get',
   				'URI' => '/data?from=' . $requestFromTimestamp,
   				'payload' => ""
			};
  		}    
    	### Command 'refreshstate'
 	  	elsif ( lc $cmd eq 'refreshstate' ) 
  	  	{
			# playload
    		$payload =
    		{
    			'method' => 'Get',
    			'URI' => '/status',
    			'payload' => ""
			};
	    }
      	### unknown Command
	    else 
    	{
        	my $list = 'refreshValues:noArg refreshState:noArg';
	        return "Unknown argument $cmd, choose one of $list";
    	}
    }
    ### unknown ###
    else 
   	{
        return "Unknown model '$model'";
   	}
    
    $hash->{helper}{deviceAction} = $payload;
    #readingsSingleUpdate( $hash, "state", "send command to grohe cloud", 1 );

	# send command via GroheOndusSmartBridge
    IOWrite( $hash, $payload, $hash->{DEVICEID}, $model );
    
    #Log3 $name, 3, "GroheOndusSmartDevice ($name) - IOWrite: $payload $hash->{DEVICEID} $model IODevHash=$hash->{IODev}";

    return undef;
}


#####################################
# This methode parses the given json string.
# If there is a defined GroheOndusSmartDevice module then the json-structure
# is passed to the methode WriteReadings.
# Else a new GroheOndusSmartDevice module is created.
sub Parse($$) 
{
    my ( $io_hash, $json ) = @_;

    my $name = $io_hash->{NAME};
    my $decode_json = eval { decode_json($json) };
    
    Log3 $name, 4, "GroheOndusSmartDevice ($name) - ParseFn was called";

    if ($@) 
    {
        Log3 $name, 3, "GroheOndusSmartDevice ($name) - JSON error while request: $@";
    }

    Log3 $name, 5, "GroheOndusSmartDevice ($name) - JSON: $json";

    if ( defined( $decode_json->{appliance_id} ) ) 
    {
        my $deviceId = $decode_json->{appliance_id};

        # SmartDevice with $deviceId found:
        if ( my $hash = $modules{GroheOndusSmartDevice}{defptr}{$deviceId} ) 
        {
            my $dname = $hash->{NAME};

            Log3 $dname, 5, "GroheOndusSmartDevice ($dname) - find logical device: $hash->{NAME}";

			# process json structure
           	WriteReadings( $hash, $decode_json );

			# change state to "connected to cloud" -> Notify -> load timer
		    readingsBeginUpdate($hash);
    		readingsBulkUpdateIfChanged( $hash, 'state', 'connected to cloud', 1 );
		    readingsEndUpdate($hash, 1 );

            return $dname;
        }
        # SmartDevice not found, create new one
        else 
        {
 	    	#[
	    	#	{
	    	#		"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    		#		"installation_date":"2001-01-30T00:00:00.000+00:00",
	    	#		"name":"KG Vorratsraum - SenseGUARD",
    		#		"serial_number":"123456789012345678901234567890123456789012345678",
	    	#		"type":103,
    		#		"version":"01.38.Z22.0400.0101",
	    	#		"tdt":"2019-06-30T11:06:40.000+02:00",
	    	#		"timezone":60,
    		#		"config":
	    	#		{
    		#			"thresholds":
	    	#			[
    		#				{
	    	#					"quantity":"flowrate",
    		#					"type":"min",
    		#					"value":3,
	    	#					"enabled":false
    		#				},
    		#				{
	    	#					"quantity":"flowrate",
    		#					"type":"max",
    		#					"value":50,
	    	#					"enabled":true
    		#				},
    		#				{
	    	#					"quantity":"pressure",
    		#					"type":"min",
    		#					"value":2,
	    	#					"enabled":false
	    	#				},
    		#				{
    		#					"quantity":"pressure",
	    	#					"type":"max",
    		#					"value":8,
    		#					"enabled":false
	    	#				},
    		#				{
    		#					"quantity":"temperature_guard",
	    	#					"type":"min",
    		#					"value":5,
    		#					"enabled":false
	    	#				},
    		#				{
    		#					"quantity":"temperature_guard",
	    	#					"type":"max",
    		#					"value":45,
    		#					"enabled":false
	    	#				}
    		#			],
    		#		"measurement_period":900,
	    	#		"measurement_transmission_intervall":900,
    		#		"measurement_transmission_intervall_offset":1,
    		#		"action_on_major_leakage":1,
	    	#		"action_on_minor_leakage":1,
    		#		"action_on_micro_leakage":0,
    		#		"monitor_frost_alert":true,
	    	#		"monitor_lower_flow_limit":false,
    		#		"monitor_upper_flow_limit":true,
    		#		"monitor_lower_pressure_limit":false,
	    	#		"monitor_upper_pressure_limit":false,
    		#		"monitor_lower_temperature_limit":false,
    		#		"monitor_upper_temperature_limit":false,
	    	#		"monitor_major_leakage":true,
    		#		"monitor_minor_leakage":true,
    		#		"monitor_micro_leakage":true,
	    	#		"monitor_system_error":false,
    		#		"monitor_btw_0_1_and_0_8_leakage":true,
    		#		"monitor_withdrawel_amount_limit_breach":true,
	    	#		"detection_interval":11250,
    		#		"impulse_ignore":10,
    		#		"time_ignore":20,
	    	#		"pressure_tolerance_band":10,
    		#		"pressure_drop":50,
    		#		"detection_time":30,
	    	#		"action_on_btw_0_1_and_0_8_leakage":1,
    		#		"action_on_withdrawel_amount_limit_breach":1,
    		#		"withdrawel_amount_limit":300,
	    	#		"sprinkler_mode_start_time":0,
    		#		"sprinkler_mode_stop_time":1439,
    		#		"sprinkler_mode_active_monday":false,
	    	#		"sprinkler_mode_active_tuesday":false,
    		#		"sprinkler_mode_active_wednesday":false,
    		#		"sprinkler_mode_active_thursday":false,
	    	#		"sprinkler_mode_active_friday":false,
    		#		"sprinkler_mode_active_saturday":false,
    		#		"sprinkler_mode_active_sunday":false},
	    	#		"role":"owner",
    		#		"registration_complete":true,
    		#		"calculate_average_since":"2000-01-30T00:00:00.000Z"
	    	#	},
    		#	{
    		#		"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	    	#		"installation_date":"2001-01-30T00:00:00.000+00:00",
    		#		"name":"KG Vorratsraum Sense",
    		#		"serial_number":"123456789012345678901234567890123456789012345678",
	    	#		"type":101,
    		#		"version":"1547",
	    	#		"tdt":"2019-06-30T05:15:38.000+02:00",
    		#		"timezone":60,
    		#		"config":
	    	#		{
    		#			"thresholds":
    		#			[
	    	#				{
    		#					"quantity":"temperature",
   			#					"type":"min",
	   		#					"value":10,
   			#					"enabled":true
   			#				},
	   		#				{
   			#					"quantity":"temperature",
   			#					"type":"max",
	   		#					"value":35,
   			#					"enabled":true
   			#				},
	   		#				{
   			#					"quantity":"humidity",
   			#					"type":"min",
	   		#					"value":30,
   			#					"enabled":true
   			#				},
	   		#				{
   			#					"quantity":"humidity",
   			#					"type":"max",
	   		#					"value":65,
   			#					"enabled":true
   			#				}
	   		#			]
    		#		},
    		#		"role":"owner",
	    	#		"registration_complete":true
    		#	}
    		#]
    	
        	my $deviceType = $decode_json->{type};
        	my $deviceTypeName;
        
    	    if($deviceType == 101)
	        {
        		$deviceTypeName = 'sense';
    	    }
	        elsif($deviceType == 103)
        	{
    	    	$deviceTypeName = 'sense_guard';
	        }
        	else
    	    {
        	    return undef;
	        }
	        
            Log3 $name, 3, "GroheOndusSmartDevice ($name) - autocreate new device " . makeDeviceName( $decode_json->{name} ) . " with applianceId $decode_json->{appliance_id}, model $deviceTypeName";

            return "UNDEFINED " . makeDeviceName( $decode_json->{name} ) . " GroheOndusSmartDevice $decode_json->{appliance_id} $deviceTypeName";
        }
    }
}

#####################################
sub WriteReadings($$) 
{
    my ( $hash, $decode_json ) = @_;

    my $name = $hash->{NAME};
    my $model = AttrVal( $name, 'model', 'unknown' );
    
    readingsBeginUpdate($hash);

	#########################################################
    ### sense ###############################################
	#########################################################
    if ( $model eq 'sense' )
   	{
   		# config:
   		#{
   		#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    	#	"installation_date":"2001-01-30T00:00:00.000+00:00",
   		#	"name":"KG Vorratsraum Sense",
   		#	"serial_number":"123456789012345678901234567890123456789012345678",
    	#	"type":101,
   		#	"version":"1547",
    	#	"tdt":"2019-06-30T05:15:38.000+02:00",
   		#	"timezone":60,
   		#	"role":"owner",
    	#	"registration_complete":true,
   		#	"config":
    	#	{
   		#		"thresholds":
    	#		[
	   	#			{
 		#				"quantity":"temperature",
		#				"type":"min",
		#				"value":10,
		#				"enabled":true
		#			},
		#			{
		#				"quantity":"temperature",
		#				"type":"max",
		#				"value":35,
		#				"enabled":true
		#			},
 		#			{
		#				"quantity":"humidity",
		#				"type":"min",
 		#				"value":30,
		#				"enabled":true
		#			},
  		#			{
		#				"quantity":"humidity",
		#				"type":"max",
  		#				"value":65,
		#				"enabled":true
		#			}
   		#		]
   		#	}
   		#}
   		#]
		if( defined( $decode_json->{config} ) )
		{
			foreach my $key (keys %{ $decode_json })
    		{
   			  if($key eq 'config')
   			  {
   			  	# skipped
   			  }
   			  elsif($key eq 'appliance_id')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceID", $decode_json->{appliance_id} );
   			  }
   			  elsif($key eq 'installation_date')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceInstallationDate", $decode_json->{installation_date} );
   			  }
   			  elsif($key eq 'name')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceName", $decode_json->{name} );
   			  }
   			  elsif($key eq 'serial_number')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceSerialNumber", $decode_json->{serial_number} );
   			  }
   			  elsif($key eq 'type')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceType", $decode_json->{type} );
   			  }
   			  elsif($key eq 'version')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceVersion", $decode_json->{version} );
   			  }
   			  elsif($key eq 'tdt')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceTDT", $decode_json->{tdt} );
   			  }
   			  elsif($key eq 'timezone')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceTimezone", $decode_json->{timezone} );
   			  }
   			  elsif($key eq 'role')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceRole", $decode_json->{role} );
   			  }
   			  elsif($key eq 'registration_complete')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceRegistrationComplete", $decode_json->{registration_complete} );
   			  }
   			  else
			  {
    			readingsBulkUpdateIfChanged( $hash, "Unknown_" . $key, $decode_json->{$key} );
			  }
    		}

			# process Thresholds
			if( defined( $decode_json->{config} ) 
			  and defined( $decode_json->{config}->{thresholds} )
			  and ref( $decode_json->{config}->{thresholds} ) eq "ARRAY" )
			{
				foreach my $currentThreshold ( @{ $decode_json->{config}->{thresholds} } ) 
    	    	{
    	    	  if( defined ( $currentThreshold->{quantity} ) 
    	    		  and defined ( $currentThreshold->{type} )
    	    		  and defined ( $currentThreshold->{value} )
    	    		  and defined ( $currentThreshold->{enabled} ) )
    	   		  {
		        	if( "$currentThreshold->{quantity}" eq "temperature" )
       				{
  					  if( "$currentThreshold->{type}" eq "max" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdTemperaturMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
  					  elsif( "$currentThreshold->{type}" eq "min" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdTemperaturMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
       				}
		        	elsif( "$currentThreshold->{quantity}" eq "humidity" )
       				{
  					  if( "$currentThreshold->{type}" eq "max" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdHumidityMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
  					  elsif( "$currentThreshold->{type}" eq "min" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdHumidityMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
       				}
    	   		  }

				  # write json string to reading "unknown-data"
				  readingsBulkUpdateIfChanged( $hash, "unknown-data", encode_json( $currentThreshold ) );
	        	}				
			}
		}    
    	# Status:
   		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
   		#	"data":
   		#	[
   		#		{
   		#			"type":"battery"
   		#			"value":100,
   		#		},
   		#		{
   		#			"type":"connection",
   		#			"value":1
   		#		},
   		#		{
   		#			"type":"wifi_quality",
   		#			"value":0
   		#		}
   		#	]
		#}
		elsif( defined( $decode_json->{data} )
		  and ref( $decode_json->{data} ) eq "ARRAY")
		{
			foreach my $data ( @{ $decode_json->{data} } ) 
        	{
        		if( "$data->{type}" eq "battery"
        		  and defined( $data->{value} ) )
        		{
    				readingsBulkUpdateIfChanged( $hash, "StateBattery", $data->{value} );
        		}
        		elsif( "$data->{type}" eq "connection"
        		  and defined( $data->{value} ) )
        		{
    				readingsBulkUpdateIfChanged( $hash, "StateConnection", $data->{value} );
        		}
        		elsif ( "$data->{type}" eq "wifi_quality"
        		  and defined( $data->{value} ) )
        		{
    				readingsBulkUpdateIfChanged( $hash, "StateWiFiQuality", $data->{value} );
        		}
        		else
        		{
        			# write json string to reading "unknown-data"
    				readingsBulkUpdateIfChanged( $hash, "unknown-data", encode_json( $data ) );
        		}
        	}
		}
 		# Data:
 		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#	"data":
		#	{
	   	#		"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#		"data":
		#		{
		#			"measurement":
		#			[
		#				{
		#					"timestamp":"2019-01-30T08:04:27.000+01:00",
		#					"humidity":54,
		#					"temperature":19.4
		#				},
		#				{
		#					"timestamp":"2019-01-30T08:04:28.000+01:00",
		#					"humidity":53,
		#					"temperature":19.4
		#				}
		#			],
		#			"withdrawals":
		#			[
		#			]
		#		},
		#		"type":101
		#	}
 		#}
		elsif( defined( $decode_json->{data} )
		  and ref( $decode_json->{data} ) eq "HASH"
		  and defined( $decode_json->{data}->{data} )
		  and ref( $decode_json->{data}->{data} ) eq "HASH"
		  and defined( $decode_json->{data}->{data}->{measurement} )
		  and ref( $decode_json->{data}->{data}->{measurement} ) eq "ARRAY")
		{
			# get entry with latest timestamp 
			my $dataTimestamp;
			my $dataHumidity;
			my $dataTemperature;
						
			foreach my $data ( @{ $decode_json->{data}->{data}->{measurement} } ) 
        	{
        		# is this the correct dataset?
        		if( defined( $data->{timestamp} )
        		  and defined( $data->{humidity} )
        		  and defined( $data->{temperature} )	)
        		{
        			# is timestamp newer? 
        			if(not defined( $dataTimestamp )
        				or $data->{timestamp} gt $dataTimestamp)
        			{
        				$dataTimestamp = $data->{timestamp};
        				$dataHumidity = $data->{humidity};
    	    			$dataTemperature = $data->{temperature};
	        		}
        		}
        	}

   			readingsBulkUpdateIfChanged( $hash, "LastDataTimestamp", $dataTimestamp )
   				if( defined($dataTimestamp) );
   			readingsBulkUpdateIfChanged( $hash, "LastHumidity", $dataHumidity )
   				if( defined($dataHumidity) );
   			readingsBulkUpdateIfChanged( $hash, "LastTemperature", $dataTemperature )
   				if( defined($dataTemperature) );
		}
		# no data available:
		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#	"data":
		#	{
		#		"message":"Not found",
		#		"code":404
		#	}
		#}
		# if no data for requested timespan is available this response is sent
	  	elsif( defined( $decode_json->{data}->{message} )
		  and defined( $decode_json->{data}->{code} )
		  and $decode_json->{data}->{code} eq 404 )
		{
		}
		##### unknown
		else
		{
   			# write json string to reading "unknown"
  			readingsBulkUpdateIfChanged( $hash, "unknown", encode_json( $decode_json ) );
		}
    } 
	#########################################################
    ### sense_guard #########################################
	#########################################################
    elsif ( $model eq 'sense_guard' )
   	{
		# config:
    	#{
    	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
   		#	"installation_date":"2001-01-30T00:00:00.000+00:00",
    	#	"name":"KG Vorratsraum - SenseGUARD",
   		#	"serial_number":"123456789012345678901234567890123456789012345678",
    	#	"type":103,
   		#	"version":"01.38.Z22.0400.0101",
    	#	"tdt":"2019-06-30T11:06:40.000+02:00",
    	#	"timezone":60,
   		#	"measurement_period":900,
    	#	"measurement_transmission_intervall":900,
   		#	"measurement_transmission_intervall_offset":1,
   		#	"action_on_major_leakage":1,
    	#	"action_on_minor_leakage":1,
   		#	"action_on_micro_leakage":0,
   		#	"monitor_frost_alert":true,
    	#	"monitor_lower_flow_limit":false,
   		#	"monitor_upper_flow_limit":true,
   		#	"monitor_lower_pressure_limit":false,
    	#	"monitor_upper_pressure_limit":false,
   		#	"monitor_lower_temperature_limit":false,
   		#	"monitor_upper_temperature_limit":false,
    	#	"monitor_major_leakage":true,
   		#	"monitor_minor_leakage":true,
   		#	"monitor_micro_leakage":true,
    	#	"monitor_system_error":false,
   		#	"monitor_btw_0_1_and_0_8_leakage":true,
   		#	"monitor_withdrawel_amount_limit_breach":true,
    	#	"detection_interval":11250,
   		#	"impulse_ignore":10,
   		#	"time_ignore":20,
    	#	"pressure_tolerance_band":10,
   		#	"pressure_drop":50,
   		#	"detection_time":30,
    	#	"action_on_btw_0_1_and_0_8_leakage":1,
   		#	"action_on_withdrawel_amount_limit_breach":1,
   		#	"withdrawel_amount_limit":300,
    	#	"sprinkler_mode_start_time":0,
   		#	"sprinkler_mode_stop_time":1439,
   		#	"sprinkler_mode_active_monday":false,
    	#	"sprinkler_mode_active_tuesday":false,
   		#	"sprinkler_mode_active_wednesday":false,
   		#	"sprinkler_mode_active_thursday":false,
    	#	"sprinkler_mode_active_friday":false,
   		#	"sprinkler_mode_active_saturday":false,
   		#	"sprinkler_mode_active_sunday":false},
    	#	"role":"owner",
   		#	"registration_complete":true,
   		#	"calculate_average_since":"2000-01-30T00:00:00.000Z",
   		#	"config":
    	#	{
   		#			"thresholds":
    	#			[
   		#				{
    	#					"quantity":"flowrate",
   		#					"type":"min",
   		#					"value":3,
    	#					"enabled":false
   		#				},
   		#				{
    	#					"quantity":"flowrate",
   		#					"type":"max",
   		#					"value":50,
    	#					"enabled":true
   		#				},
   		#				{
    	#					"quantity":"pressure",
   		#					"type":"min",
   		#					"value":2,
    	#					"enabled":false
    	#				},
   		#				{
   		#					"quantity":"pressure",
    	#					"type":"max",
   		#					"value":8,
   		#					"enabled":false
    	#				},
   		#				{
   		#					"quantity":"temperature_guard",
    	#					"type":"min",
   		#					"value":5,
   		#					"enabled":false
    	#				},
   		#				{
   		#					"quantity":"temperature_guard",
    	#					"type":"max",
   		#					"value":45,
   		#					"enabled":false
    	#				}
   		#			],
   		#		}
    	#	}
	   	if( defined( $decode_json->{config} ) )
		{
			foreach my $key (keys %{ $decode_json })
    		{
   			  if($key eq 'config')
   			  {
   			  	# skipped
   			  }
   			  elsif($key eq 'appliance_id')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceID", $decode_json->{appliance_id} );
   			  }
   			  elsif($key eq 'installation_date')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceInstallationDate", $decode_json->{installation_date} );
   			  }
   			  elsif($key eq 'name')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceName", $decode_json->{name} );
   			  }
   			  elsif($key eq 'serial_number')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceSerialNumber", $decode_json->{serial_number} );
   			  }
   			  elsif($key eq 'type')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceType", $decode_json->{type} );
   			  }
   			  elsif($key eq 'version')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceVersion", $decode_json->{version} );
   			  }
   			  elsif($key eq 'tdt')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceTDT", $decode_json->{tdt} );
   			  }
   			  elsif($key eq 'timezone')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceTimezone", $decode_json->{timezone} );
   			  }
   			  elsif($key eq 'role')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceRole", $decode_json->{role} );
   			  }
   			  elsif($key eq 'registration_complete')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ApplianceRegistrationComplete", $decode_json->{registration_complete} );
   			  }
   			  elsif($key eq 'measurement_period')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MeasurementPeriod", $decode_json->{measurement_period} );
   			  }
   			  elsif($key eq 'measurement_transmission_intervall')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MeasurementTransmissionIntervall", $decode_json->{measurement_transmission_intervall} );
   			  }
   			  elsif($key eq 'measurement_transmission_intervall_offset')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MeasurementTransmissionIntervallOffset", $decode_json->{measurement_transmission_intervall_offset} );
   			  }
   			  elsif($key eq 'action_on_major_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ActionOnMajorLeakage", $decode_json->{action_on_major_leakage} );
   			  }
   			  elsif($key eq 'action_on_minor_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ActionOnMinorLeakage", $decode_json->{action_on_minor_leakage} );
   			  }
   			  elsif($key eq 'action_on_micro_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "ActionOnMicroLeakage", $decode_json->{action_on_micro_leakage} );
   			  }
   			  elsif($key eq 'monitor_frost_alert')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorFrostAlert", $decode_json->{monitor_frost_alert} );
   			  }
   			  elsif($key eq 'monitor_lower_flow_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorLowerFlowLimit", $decode_json->{monitor_lower_flow_limit} );
   			  }
   			  elsif($key eq 'monitor_upper_flow_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorUpperFlowLimit", $decode_json->{monitor_upper_flow_limit} );
   			  }
   			  elsif($key eq 'monitor_lower_pressure_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorLowerPressureLimit", $decode_json->{monitor_lower_pressure_limit} );
   			  }
   			  elsif($key eq 'monitor_upper_pressure_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorUpperPressureLimit", $decode_json->{monitor_upper_pressure_limit} );
   			  }
   			  elsif($key eq 'monitor_lower_temperature_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorLowerTemperatureLimit", $decode_json->{monitor_lower_temperature_limit} );
   			  }
   			  elsif($key eq 'monitor_upper_temperature_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorUpperTemperatureLimit", $decode_json->{monitor_upper_temperature_limit} );
   			  }
   			  elsif($key eq 'monitor_major_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorMajorLeakage", $decode_json->{monitor_major_leakage} );
   			  }
   			  elsif($key eq 'monitor_minor_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorMinorLeakage", $decode_json->{monitor_minor_leakage} );
   			  }
   			  elsif($key eq 'monitor_micro_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorMicroLeakage", $decode_json->{monitor_micro_leakage} );
   			  }
   			  elsif($key eq 'monitor_system_error')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorSystemError", $decode_json->{monitor_system_error} );
   			  }
   			  elsif($key eq 'monitor_btw_0_1_and_0_8_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "Monitor_btw_0_1_and_0_8_leakage", $decode_json->{monitor_btw_0_1_and_0_8_leakage} );
   			  }
   			  elsif($key eq 'monitor_withdrawel_amount_limit_breach')
   			  {
				readingsBulkUpdateIfChanged( $hash, "MonitorWithdrawelAmountLimitBreach", $decode_json->{monitor_withdrawel_amount_limit_breach} );
   			  }
   			  elsif($key eq 'detection_interval')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionInterval", $decode_json->{detection_interval} );
   			  }
   			  elsif($key eq 'impulse_ignore')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionImpulseIgnore", $decode_json->{impulse_ignore} );
   			  }
   			  elsif($key eq 'time_ignore')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionTimeIgnore", $decode_json->{time_ignore} );
   			  }
   			  elsif($key eq 'pressure_tolerance_band')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionPressureToleranceBand", $decode_json->{pressure_tolerance_band} );
   			  }
   			  elsif($key eq 'pressure_drop')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionPressureDrop", $decode_json->{pressure_drop} );
   			  }
   			  elsif($key eq 'detection_time')
   			  {
				readingsBulkUpdateIfChanged( $hash, "DetectionTime", $decode_json->{detection_time} );
   			  }
   			  elsif($key eq 'action_on_btw_0_1_and_0_8_leakage')
   			  {
				readingsBulkUpdateIfChanged( $hash, "Action_on_btw_0_1_and_0_8_leakage", $decode_json->{action_on_btw_0_1_and_0_8_leakage} );
   			  }
   			  elsif($key eq 'action_on_withdrawel_amount_limit_breach')
   			  {
				readingsBulkUpdateIfChanged( $hash, "Action_on_withdrawel_amount_limit_breach", $decode_json->{action_on_withdrawel_amount_limit_breach} );
   			  }
   			  elsif($key eq 'withdrawel_amount_limit')
   			  {
				readingsBulkUpdateIfChanged( $hash, "WithdrawelAmountLimit", $decode_json->{withdrawel_amount_limit} );
   			  }
   			  elsif($key eq 'sprinkler_mode_start_time')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeStartTime", $decode_json->{sprinkler_mode_start_time} );
   			  }
   			  elsif($key eq 'sprinkler_mode_stop_time')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeStopTime", $decode_json->{sprinkler_mode_stop_time} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_monday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveMonday", $decode_json->{sprinkler_mode_active_monday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_tuesday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveTuesday", $decode_json->{sprinkler_mode_active_tuesday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_wednesday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveWednesday", $decode_json->{sprinkler_mode_active_wednesday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_thursday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveThursday", $decode_json->{sprinkler_mode_active_thursday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_friday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveFriday", $decode_json->{sprinkler_mode_active_friday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_saturday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveSaturday", $decode_json->{sprinkler_mode_active_saturday} );
   			  }
   			  elsif($key eq 'sprinkler_mode_active_sunday')
   			  {
				readingsBulkUpdateIfChanged( $hash, "SprinklerModeActiveSunday", $decode_json->{sprinkler_mode_active_sunday} );
   			  }
   			  elsif($key eq 'calculate_average_since')
   			  {
				readingsBulkUpdateIfChanged( $hash, "CalculateAverageSince", $decode_json->{calculate_average_since} );
   			  }
   			  else
			  {
    			readingsBulkUpdateIfChanged( $hash, "Unknown_" . $key, $decode_json->{$key} );
			  }
    		}
    		
			# process thresholds
			if( defined( $decode_json->{config} ) 
			  and defined( $decode_json->{config}->{thresholds} )
			  and ref( $decode_json->{config}->{thresholds} ) eq "ARRAY" )
			{
				foreach my $currentThreshold ( @{ $decode_json->{config}->{thresholds} } ) 
    	    	{
    	    	  if( defined ( $currentThreshold->{quantity} ) 
    	    		  and defined ( $currentThreshold->{type} )
    	    		  and defined ( $currentThreshold->{value} )
    	    		  and defined ( $currentThreshold->{enabled} ) )
    	   		  {
		        	if( "$currentThreshold->{quantity}" eq "flowrate" )
       				{
  					  if( "$currentThreshold->{type}" eq "max" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdFlowrateMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
  					  elsif( "$currentThreshold->{type}" eq "min" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdFlowrateMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
       				}
		        	elsif( "$currentThreshold->{quantity}" eq "pressure" )
       				{
  					  if( "$currentThreshold->{type}" eq "max" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdPressureMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
  					  elsif( "$currentThreshold->{type}" eq "min" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdPressureMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
       				}
		        	elsif( "$currentThreshold->{quantity}" eq "temperature_guard" )
       				{
  					  if( "$currentThreshold->{type}" eq "max" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdTemperatureGuardMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
  					  elsif( "$currentThreshold->{type}" eq "min" )
  					  {
   					    readingsBulkUpdateIfChanged( $hash, "ThresholdTemperatureGuardMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
   					    next;
  					  }
       				}
    	   		  }

				  # write json string to reading "unknown-data"
				  readingsBulkUpdateIfChanged( $hash, "unknown-data", encode_json( $currentThreshold ) );
	        	}				
			}
		}    
   		# Status:
		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#	"data":
		#	[
		#		{
		#			"type":"update_available",
		#			"value":0
		#		},
		#		{
		#			"type":"connection",
		#			"value":1
		#		}
		#	]
		#}
		elsif( defined( $decode_json->{data} )
		  and ref( $decode_json->{data} ) eq "ARRAY" )
		{
			foreach my $data ( @{ $decode_json->{data} } ) 
        	{
	       		if( $data->{type} eq "update_available"
    	   		  and defined($data->{value} ) )
       			{
   					readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $data->{value} );
	       		}
    	   		elsif( $data->{type} eq "connection"
       			  and defined($data->{value} ) )
       			{
	   				readingsBulkUpdateIfChanged( $hash, "StateConnection", $data->{value} );
    	   		}
       			else
       			{
        			# write json string to reading "unknown"
    				readingsBulkUpdateIfChanged( $hash, "unknown-data", encode_json( $data ) );
       			}
        	}
		}
   		# ApplianceCommand:
		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
   		#	"data":
		#	{
		#		"commandb64":"AgI=",
  		#		"command":
		#		{
		#			"buzzer_on":false,
  		#			"measure_now":false,
		#			"temp_user_unlock_on":false,
		#			"valve_open":true,
  		#			"buzzer_sound_profile":2
		#		},
		#		"timestamp":"2019-08-07T04:17:02.985Z",
	   	#		"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
   		#		"type":103
   		#	}
		#}
		elsif( defined( $decode_json->{data} )
		  and ref( $decode_json->{data} ) eq "HASH"
		  and defined( $decode_json->{data}->{command} )
		  and ref( $decode_json->{data}->{command} ) eq "HASH" 
		  and defined( $decode_json->{data}->{command}->{buzzer_on} )
		  and defined( $decode_json->{data}->{command}->{measure_now} )
		  and defined( $decode_json->{data}->{command}->{temp_user_unlock_on} )
		  and defined( $decode_json->{data}->{command}->{valve_open} )
		  and defined( $decode_json->{data}->{command}->{buzzer_sound_profile} ) )
		{
			my $measure_now = $decode_json->{data}->{command}->{measure_now};
			my $temp_user_unlock_on = $decode_json->{data}->{command}->{temp_user_unlock_on};
			my $valve_open = $decode_json->{data}->{command}->{valve_open};
			my $buzzer_on = $decode_json->{data}->{command}->{buzzer_on};
			my $buzzer_sound_profile = $decode_json->{data}->{command}->{buzzer_sound_profile};
			
			# update readings
			readingsBulkUpdateIfChanged( $hash, "CmdMeasureNow", "$measure_now" );
			readingsBulkUpdateIfChanged( $hash, "CmdTempUserUnlockOn", "$temp_user_unlock_on" );
			readingsBulkUpdateIfChanged( $hash, "CmdValveOpen", "$valve_open" );
			readingsBulkUpdateIfChanged( $hash, "CmdBuzzerOn", "$buzzer_on" );
			readingsBulkUpdateIfChanged( $hash, "CmdBuzzerSoundProfile", "$buzzer_sound_profile" );
		}
		# Data
		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#	"data":
		#	{
	   	#		"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#		"data":
		#		{
		#			"measurement":
		#			[
		#				{
		#					"timestamp":"2019-07-14T02:07:36.000+02:00",
		#					"flowrate":0,
		#					"temperature_guard":22.5,
		#					"pressure":3
		#				},
		#				{
		#					"timestamp":"2019-07-14T02:22:36.000+02:00",
		#					"temperature_guard":22.5,
		#					"flowrate":0,
		#					"pressure":3
		#				}
		#			],
		#			"withdrawals":
		#			[
		#				{
		#					"water_cost":0.01447,
		#					"hotwater_share":0,
		#					"waterconsumption":3.4,
		#					"stoptime":"2019-07-14T03:16:51.000+02:00",
		#					"starttime":"2019-07-14T03:16:24.000+02:00",
		#					"maxflowrate":10.7,
		#					"energy_cost":0
		#				},
		#				{
		#					"waterconsumption":7.6,
		#					"hotwater_share":0,
		#					"energy_cost":0,
		#					"starttime":"2019-07-14T03:58:19.000+02:00",
		#					"stoptime":"2019-07-14T03:59:13.000+02:00",
		#					"maxflowrate":10.9,
		#					"water_cost":0.032346
		#				}
		#			]
		#		},
		#		"type":103
		#	}
		#}
		elsif( defined( $decode_json->{data} )
		  and ref( $decode_json->{data} ) eq "HASH"
		  and defined( $decode_json->{data}->{data} )
		  and ref( $decode_json->{data}->{data} ) eq "HASH" )
		{
			# Measurement
	  		if( defined( $decode_json->{data}->{data}->{measurement} )
		      and ref( $decode_json->{data}->{data}->{measurement} ) eq "ARRAY" )
			{
				# get entry with latest timestamp 
				my $dataTimestamp;
				my $dataFlowrate;
				my $dataTemperature;
				my $dataPressure;
						
				foreach my $data ( @{ $decode_json->{data}->{data}->{measurement} } ) 
   	    		{
       				# is this the correct dataset?
       				if( defined( $data->{timestamp} )
   	    			  and defined( $data->{flowrate} )
	        		  and defined( $data->{temperature_guard} )
   		    		  and defined( $data->{pressure} ) )
   	    			{
        				# is timestamp newer? 
       					if(not defined( $dataTimestamp )
       					  or $data->{timestamp} gt $dataTimestamp)
        				{
   	    					$dataTimestamp = $data->{timestamp};
       						$dataFlowrate = $data->{flowrate};
   		    				$dataTemperature = $data->{temperature_guard};
    	    				$dataPressure = $data->{pressure};
        				}
        			}
   	    		}

				readingsBulkUpdateIfChanged( $hash, "LastDataTimestamp", $dataTimestamp )
				  if( defined($dataTimestamp) );
   				readingsBulkUpdateIfChanged( $hash, "LastFlowrate", $dataFlowrate )
				  if( defined($dataFlowrate) );
				readingsBulkUpdateIfChanged( $hash, "LastTemperature", $dataTemperature )
				  if( defined($dataTemperature) );
				readingsBulkUpdateIfChanged( $hash, "LastPressure", $dataPressure )
   				  if( defined($dataPressure) );
			}
			# withdrawals
		  	if( defined( $decode_json->{data}->{data}->{withdrawals} )
	    	  and ref( $decode_json->{data}->{data}->{withdrawals} ) eq "ARRAY" )
			{
				# analysis
				my $dataAnalyzeStartTimestamp;
				my $dataAnalyzeStopTimestamp;
				my $dataAnalyzeCount = 0;

				# get entry with latest timestamp 
				my $dataLastStartTimestamp;
				my $dataLastStopTimestamp;
				my $dataLastWaterconsumption;
				my $dataLastMaxflowrate;
				my $dataLastHotwaterShare;
				my $dataLastWaterCost;
				my $dataLastEnergyCost;

				# result of today 
				my $dataTodayAnalyzeStartTimestamp;
				my $dataTodayAnalyzeStopTimestamp;
				my $dataTodayAnalyzeCount = 0;
				my $dataTodayWaterconsumption = 0;
				my $dataTodayMaxflowrate = 0;
				my $dataTodayHotwaterShare = 0;
				my $dataTodayWaterCost = 0;
				my $dataTodayEnergyCost = 0;
					
				# get current date	
				my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(gettimeofday());
   				my $today_ymd = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $mday);
   				my $tomorrow_ymd = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $mday+1); # day > 31 is OK for stringcompare
						
				# my convention: dataset contains all withdrawals of today
				foreach my $data ( @{ $decode_json->{data}->{data}->{withdrawals} } ) 
   	    		{
       				# is it the right dataset?
   	    			if( defined( $data->{starttime} )
        			  and defined( $data->{stoptime} )
        			  and defined( $data->{waterconsumption} )
   	    			  and defined( $data->{maxflowrate} ) 
   	    			  and defined( $data->{hotwater_share} )
   		    		  and defined( $data->{water_cost} )
   		    		  and defined( $data->{energy_cost} ) )
        			{
        				$dataAnalyzeCount += 1;
	        				
        				# find first timestamp of analysis? 
       					if(not defined( $dataAnalyzeStartTimestamp )
   	    				  or $data->{starttime} lt $dataAnalyzeStartTimestamp)
	        			{
	        				$dataAnalyzeStartTimestamp = $data->{starttime};
	        			}

        				# find last timestamp of analysis? 
       					if(not defined( $dataAnalyzeStopTimestamp )
   	    				  or $data->{stoptime} gt $dataAnalyzeStopTimestamp)
	        			{
	        				$dataAnalyzeStopTimestamp = $data->{stoptime};
	        			}
	        				
       					# is timestamp younger? 
       					if(not defined( $dataLastStartTimestamp )
   	    				  or $data->{starttime} gt $dataLastStartTimestamp)
	        			{
   	    					$dataLastStartTimestamp = $data->{starttime};
       						$dataLastStopTimestamp = $data->{stoptime};
   	    					$dataLastWaterconsumption = $data->{waterconsumption};
   	    					$dataLastMaxflowrate = $data->{maxflowrate};
   	    					$dataLastHotwaterShare = $data->{hotwater_share};
   		    				$dataLastWaterCost = $data->{water_cost};
   		    				$dataLastEnergyCost = $data->{energy_cost};
	        			}
	        			
        				# is dataset within today?
        				#   $today_ymd         2019-08-31
        				#   $data->{starttime} 2019-08-31T03:58:19.000+02:00
        				#   $tomorrow_ymd      2019-08-32 -> OK for stringcompare
        				if($data->{starttime} gt $today_ymd
        				  and $data->{starttime} lt $tomorrow_ymd)
        				{
        					# find first timestamp of today? 
       						if(not defined( $dataTodayAnalyzeStartTimestamp )
   	    				  	  or $data->{starttime} lt $dataTodayAnalyzeStartTimestamp)
	        				{
	        					$dataTodayAnalyzeStartTimestamp = $data->{starttime};
	        				}

        					# find last timestamp of today? 
       						if(not defined( $dataTodayAnalyzeStopTimestamp )
   	    				  	  or $data->{stoptime} gt $dataTodayAnalyzeStopTimestamp)
	        				{
	        					$dataTodayAnalyzeStopTimestamp = $data->{stoptime};
	        				}
	        					
        					$dataTodayAnalyzeCount += 1;
							$dataTodayWaterconsumption += $data->{waterconsumption};
							$dataTodayHotwaterShare += $data->{hotwater_share};
							$dataTodayWaterCost += $data->{water_cost};
							$dataTodayEnergyCost += $data->{energy_cost};
							$dataTodayMaxflowrate = ($dataTodayMaxflowrate, $data->{maxflowrate})[$dataTodayMaxflowrate < $data->{maxflowrate}]; # get maximum
        				}
	        		}
    	    	}

				# analysis
				readingsBulkUpdateIfChanged( $hash, "AnalyzeStartTimestamp", $dataAnalyzeStartTimestamp )
				  if( defined($dataAnalyzeStartTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "AnalyzeStopTimestamp", $dataAnalyzeStopTimestamp )
				  if( defined($dataAnalyzeStopTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "AnalyzeCount", $dataAnalyzeCount );

				# last dataset
				readingsBulkUpdateIfChanged( $hash, "LastRequestFromTimestampGMT", $hash->{helper}{lastrequestfromtimestamp} )
				  if( defined($hash->{helper}{lastrequestfromtimestamp}) );
				readingsBulkUpdateIfChanged( $hash, "OffsetLocalTimeGMTime", $hash->{helper}{offsetLocalTimeGMTime} )
				  if( defined($hash->{helper}{offsetLocalTimeGMTime}) );
				readingsBulkUpdateIfChanged( $hash, "LastStartTimestamp", $dataLastStartTimestamp )
				  if( defined($dataLastStartTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "LastStopTimestamp", $dataLastStopTimestamp )
				  if( defined($dataLastStopTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "LastWaterConsumption", $dataLastWaterconsumption )
				  if( defined($dataLastWaterconsumption) );
				readingsBulkUpdateIfChanged( $hash, "LastMaxFlowRate", $dataLastMaxflowrate )
				  if( defined($dataLastMaxflowrate) );
  				readingsBulkUpdateIfChanged( $hash, "LastHotWaterShare", $dataLastHotwaterShare )
				  if( defined($dataLastHotwaterShare) );
				readingsBulkUpdateIfChanged( $hash, "LastWaterCost", $dataLastWaterCost )
				  if( defined($dataLastWaterCost) );
				readingsBulkUpdateIfChanged( $hash, "LastEnergyCost", $dataLastEnergyCost )
  				  if( defined($dataLastEnergyCost) );

				# today's values
				readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeStartTimestamp", $dataTodayAnalyzeStartTimestamp )
				  if( defined($dataTodayAnalyzeStartTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeStopTimestamp", $dataTodayAnalyzeStopTimestamp )
				  if( defined($dataTodayAnalyzeStopTimestamp) );
				readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeCount", $dataTodayAnalyzeCount );
				readingsBulkUpdateIfChanged( $hash, "TodayWaterConsumption", $dataTodayWaterconsumption );
				readingsBulkUpdateIfChanged( $hash, "TodayMaxFlowRate", $dataTodayMaxflowrate );
  				readingsBulkUpdateIfChanged( $hash, "TodayHotWaterShare", $dataTodayHotwaterShare );
				readingsBulkUpdateIfChanged( $hash, "TodayWaterCost", $dataTodayWaterCost );
				readingsBulkUpdateIfChanged( $hash, "TodayEnergyCost", $dataTodayEnergyCost );
			}
		}
		# no data available:
		#{
	   	#	"appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		#	"data":
		#	{
		#		"message":"Not found",
		#		"code":404
		#	}
		#}
		# if no data for requested timespan is available this response is sent
	  	elsif( defined( $decode_json->{data}->{message} )
		  and defined( $decode_json->{data}->{code} )
		  and $decode_json->{data}->{code} eq 404 )
		{
		}
		##### unknown
		else
		{
   			# write json string to reading "unknown"
  			readingsBulkUpdateIfChanged( $hash, "unknown", encode_json( $decode_json ) );
		}
    }

    readingsEndUpdate( $hash, 1 );

    Log3 $name, 5, "GroheOndusSmartDevice ($name) - readings was written";
}

##################################
sub updateValues($) 
{
    my $hash = shift;
    my $name = $hash->{NAME};
    my $interval  = $hash->{INTERVAL};
    my $model = AttrVal( $name, 'model', 'unknown' );

    RemoveInternalTimer($hash);

    if ( not IsDisabled($name) ) 
    {
        Log3 $name, 4, "GroheOndusSmartDevice ($name) - update Values";

    	### sense ###
	    if ( $model eq 'sense' )
   		{
   			# send commands to cloud
	       	Set( $hash, $name, "refreshstate", undef );
    	    Set( $hash, $name, "refreshvalues", undef );
	   	}
    	### sense_guard ###
    	elsif ( $model eq 'sense_guard' )
	   	{
   			# send commands to cloud
	       	Set( $hash, $name, "refreshstate", undef );
    	    Set( $hash, $name, "refreshvalues", undef );
    	    Set( $hash, $name, "getappliancecommand", undef );
	   	}
	   	
	   	# reload timer
      	InternalTimer( gettimeofday() + $interval, "FHEM::GroheOndusSmartDevice::updateValues", $hash );
    }
    else 
    {
        readingsSingleUpdate( $hash, 'state', 'disabled', 1 );
        
        Log3 $name, 3, "GroheOndusSmartDevice ($name) - device is disabled";
    }
}

##################################
# This methode calculates the offset in hours from GMT and localtime
# returns ($offsetLocalTimeGMT_hours)
sub getGMTOffset() 
{
	# it seems that the timestamp for this command has to be in GMT
   	# we want to request all data from within the current day beginning from 00:00:00
   	# so we need to transform the current date 00:00:00 to GMT
	# localtime           -> request GMT
	# 2019.31.08T23:xx:xx -> 2019.30.08T22:00:00
  	# 2019.01.09T00:xx:xx -> 2019.30.08T22:00:00
	# 2019.01.09T01:xx:xx -> 2019.30.08T22:00:00
	# 2019.01.09T02:xx:xx -> 2019.31.08T22:00:00
  	# 2019.01.09T03:xx:xx -> 2019.31.08T22:00:00
	my $currentTimestamp = gettimeofday();
   	
	# calculate the offset between localtime and GMT in hours
  	#my $offsetLocalTimeGMTime = localtime($currentTimestamp) - gmtime($currentTimestamp);
	my $offsetLocalTimeGMT_hours = ( localtime $currentTimestamp + 3600*( 12 - (gmtime)[2] ) )[2] - 12;
    	
	return ( $offsetLocalTimeGMT_hours );
}

##################################
# This methode returns today's date convertet to GMT
# returns $gmtMidnightDate
sub getGMTMidnightDate() 
{
	# it seems that the timestamp for this command has to be in GMT
   	# we want to request all data from within the current day beginning from 00:00:00
   	# so we need to transform the current date 00:00:00 to GMT
	# localtime           -> request GMT
	# 2019.31.08T23:xx:xx -> 2019.30.08T22:00:00
  	# 2019.01.09T00:xx:xx -> 2019.30.08T22:00:00
	# 2019.01.09T01:xx:xx -> 2019.30.08T22:00:00
	# 2019.01.09T02:xx:xx -> 2019.31.08T22:00:00
  	# 2019.01.09T03:xx:xx -> 2019.31.08T22:00:00
	my $currentTimestamp = gettimeofday();
   	
	# calculate the offset between localtime and GMT in hours
	my $offsetLocalTimeGMT_hours = getGMTOffset();

	# current date in Greenwich
	my ($d,$m,$y) = (gmtime($currentTimestamp))[3,4,5];
	# Greenwich's date minus offset
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime(timegm(0,0,0,$d,$m,$y) - $offsetLocalTimeGMT_hours * 3600);

	# today -> get all data from within this day
	#my $requestFromTimestamp = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $mday);
    my $gmtMidnightDate = sprintf("%04d-%02d-%02dT%02d:00:00", $year+1900, $month+1, $mday, $hour);

	return $gmtMidnightDate;
}

1;

=pod

=item device
=item summary    Modul to control GroheOndusSmart Devices
=item summary_DE Modul zur Steuerung von GroheOndusSmartger&aumlten

=begin html

<a name="GroheOndusSmartDevice"></a>
<h3>GroheOndusSmartDevice</h3>
<ul>
    In combination with GroheOndusSmartBridge this FHEM Module controls the GroheOndusSmart Device using the GroheOndusCloud
    <br><br>
    Once the Bridge device is created, the connected devices are automatically recognized and created in FHEM. <br>
    From now on the devices can be controlled and changes in the GroheOndusAPP are synchronized with the state and readings of the devices.
    <a name="GroheOndusSmartDevicereadings"></a>
    <br><br><br>
    <b>Readings</b>
    <ul>
        <li>ApplianceID - ID of the device</li>
        <li>ApplianceInstallationDate - installation date of the device</li>
        <li>ApplianceName - name of the device set with GroheOndusAPP</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceattributes"></a>
    <b>Attributes</b>
    <ul>
        <li>model - model of the device: sense/sense_guard</li>
        <li>interval - Interval in seconds</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceset"></a>
    <b>set</b>
    <ul>
        <li>refreshState</li>
        <li>refreshValues</li>
    </ul>
</ul>

=end html
=begin html_DE

<a name="GroheOndusSmartDevice"></a>
<h3>GroheOndusSmartDevice</h3>
<ul>
    Zusammen mit dem Device GroheOndusSmartDevice stellt dieses FHEM Modul die Kommunikation zwischen der GroheOndusCloud und Fhem her.
    <br><br>
    Wenn das GroheOndusSmartBridge Device erzeugt wurde, werden verbundene Ger&auml;te automatisch erkannt und in Fhem angelegt.<br> 
    Von nun an k&ouml;nnen die eingebundenen Ger&auml;te gesteuert werden. &Auml;nderungen in der APP werden mit den Readings und dem Status syncronisiert.
    <a name="GroheOndusSmartDevicereadings"></a>
    </ul>
    <br>
    <ul>
    <b>Readings</b>
    <ul>
        <li>ApplianceID - ID des Ger&auml;tes</li>
        <li>ApplianceInstallationDate - Installationdatum des Ger&auml;tes</li>
        <li>ApplianceName - Name des Ger&auml;tes, der in der GroheOndusAPP gesetzt wurde</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceattributes"></a>
    <b>Attribute</b>
    <ul>
        <li>model - Modell des Ger&auml;tes: sense/sense_guard</li>
        <li>interval - Abfrageintervall in Sekunden</li>
    </ul>
    <a name="GroheOndusSmartDeviceset"></a>
    <b>set</b>
    <ul>
        <li>refreshState</li>
        <li>refreshValues</li>
    </ul>
</ul>

=end html_DE

=for :application/json;q=META.json 74_GroheOndusSmartDevice.pm
{
  "abstract": "Modul to control GroheOndusSmart Devices",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Steuerung von GroheOndus Smart Ger&aumlten"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "GroheOndus",
    "Smart"
  ],
  "release_status": "stable",
  "license": "GPL_2",
  "author": [
    "J0EK3R <J0EK3R@gmx.net>"
  ],
  "x_fhem_maintainer": [
    ""
  ],
  "x_fhem_maintainer_github": [
    "J0EK3R"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.016, 
        "Meta": 0,
        "JSON": 0,
        "Time::Local": 0
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json

=cut
