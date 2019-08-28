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
# $Id: 73_GroheOndusSmartBridge.pm 19641 2019-06-18 14:47:13Z CoolTux $
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

package FHEM::GroheOndusSmartBridge;
use GPUtils qw(GP_Import)
  ;    # wird für den Import der FHEM Funktionen aus der fhem.pl benötigt

use strict;
use warnings;
use POSIX;
use FHEM::Meta;

use HttpUtils;
our $VERSION = '1.0.0';

my $missingModul = '';
eval "use Encode qw(encode encode_utf8 decode_utf8);1"
  or $missingModul .= "Encode ";

# eval "use JSON;1"            or $missingModul .= 'JSON ';
eval "use IO::Socket::SSL;1" or $missingModul .= 'IO::Socket::SSL ';

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval {
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
};

if ($@) {
    $@ = undef;

    # try to use JSON wrapper
    #   for chance of better performance
    eval {

        # JSON preference order
        local $ENV{PERL_JSON_BACKEND} =
          'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
          unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

        require JSON;
        import JSON qw( decode_json encode_json );
        1;
    };

    if ($@) {
        $@ = undef;

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        };

        if ($@) {
            $@ = undef;

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            };

            if ($@) {
                $@ = undef;

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                };

                if ($@) {
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
BEGIN {

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
          CommandDefMod
          modules
          setKeyValue
          getKeyValue
          getUniqueId
          RemoveInternalTimer
          readingFnAttributes
          InternalTimer
          defs
          init_done
          IsDisabled
          deviceEvents
          HttpUtils_NonblockingGet
          gettimeofday
          Dispatch)
    );
}

#####################################
# _Export - Export references to main context using a different naming schema
sub _Export {
    no strict qw/refs/;    ## no critic
    my $pkg  = caller(0);
    my $main = $pkg;
    $main =~ s/^(?:.+::)?([^:]+)$/main::$1\_/g;
    foreach (@_) {
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
    $hash->{WriteFn}   = 'FHEM::GroheOndusSmartBridge::Write';
    $hash->{Clients}   = 'GroheOndusSmartDevice';
    $hash->{MatchList} = { '1:GroheOndusSmartDevice' => '"appliance_id":".*' };

    # Consumer
    $hash->{SetFn}    = 'FHEM::GroheOndusSmartBridge::Set';
    $hash->{DefFn}    = 'FHEM::GroheOndusSmartBridge::Define';
    $hash->{UndefFn}  = 'FHEM::GroheOndusSmartBridge::Undef';
    $hash->{DeleteFn} = 'FHEM::GroheOndusSmartBridge::Delete';
    $hash->{RenameFn} = 'FHEM::GroheOndusSmartBridge::Rename';
    $hash->{NotifyFn} = 'FHEM::GroheOndusSmartBridge::Notify';

    $hash->{AttrFn} = 'FHEM::GroheOndusSmartBridge::Attr';
    $hash->{AttrList} =
        'debugJSON:0,1 '
      . 'disable:1 '
      . 'interval '
      . 'disabledForIntervals '
      . 'groheOndusAccountEmail '
      . 'groheOndusBaseURL '
      . $readingFnAttributes;

    foreach my $d ( sort keys %{ $modules{GroheOndusSmartBridge}{defptr} } ) 
    {
    	my $hash = $modules{GroheOndusSmartBridge}{defptr}{$d};
    	$hash->{VERSION} = $VERSION;
    }

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

#####################################
sub Define($$) 
{
    my ( $hash, $def ) = @_;

    my @a = split( '[ \t][ \t]*', $def );

    return $@ 
      unless ( FHEM::Meta::SetInternals($hash) );
    
    return 'too few parameters: define <NAME> GroheOndusSmartBridge'
      if ( @a != 2 );
    
    return
        'Cannot define GroheOndus Bridge device. Perl modul '
      . ${missingModul}
      . ' is missing.'
      if ($missingModul);

    my $name = $a[0];
    $hash->{BRIDGE} = 1;
    $hash->{URL} =
      AttrVal( $name, 'groheOndusBaseURL',
        'https://idp-apigw.cloud.grohe.com' )
      . '/v2';
    $hash->{VERSION}   = $VERSION;
    $hash->{INTERVAL}  = 60;
    $hash->{NOTIFYDEV} = "global,$name";

    CommandAttr( undef, $name . ' room GroheOndusSmart' )
      if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

    readingsSingleUpdate( $hash, 'token', 'none',        1 );
    readingsSingleUpdate( $hash, 'state', 'initialized', 1 );

    Log3 $name, 3, "GroheOndusSmartBridge ($name) - defined GroheOndusSmartBridge";

    $modules{GroheOndusSmartBridge}{defptr}{BRIDGE} = $hash;

    return undef;
}

#####################################
# Undef( $hash, $name )
sub Undef($$) 
{
    my ( $hash, $name ) = @_;

    RemoveInternalTimer($hash);
    
    delete $modules{GroheOndusSmartBridge}{defptr}{BRIDGE}
      if ( defined( $modules{GroheOndusSmartBridge}{defptr}{BRIDGE} ) );

    return undef;
}

#####################################
# Delete( $hash, $name )
sub Delete($$) 
{
    my ( $hash, $name ) = @_;

    setKeyValue( $hash->{TYPE} . '_' . $name . '_passwd', undef );
    return undef;
}

#####################################
# ATTR($cmd, $name, $attrName, $attrVal)
sub Attr(@) 
{
    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};

    Log3 $name, 4, "GroheOndusSmartBridge ($name) - Attr was called";

	# Attribute "disable"
    if ( $attrName eq 'disable' ) 
    {
        if ( $cmd eq 'set' and $attrVal eq '1' ) 
        {
            RemoveInternalTimer($hash);
            readingsSingleUpdate( $hash, 'state', 'inactive', 1 );
            Log3 $name, 3, "GroheOndusSmartBridge ($name) - disabled";
        }
        elsif ( $cmd eq 'del' ) 
        {
            readingsSingleUpdate( $hash, 'state', 'active', 1 );
            Log3 $name, 3, "GroheOndusSmartBridge ($name) - enabled";
        }
    }
	# Attribute "disabledForIntervals"
    elsif ( $attrName eq 'disabledForIntervals' ) 
    {
        if ( $cmd eq 'set' ) 
        {
            return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
              unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );
    
            Log3 $name, 3, "GroheOndusSmartBridge ($name) - disabledForIntervals";
        }
        elsif ( $cmd eq 'del' ) 
        {
            readingsSingleUpdate( $hash, 'state', 'active', 1 );
            Log3 $name, 3, "GroheOndusSmartBridge ($name) - enabled";
        }
    }
	# Attribute "interval"
    elsif ( $attrName eq 'interval' ) 
    {
        if ( $cmd eq 'set' ) 
        {
            RemoveInternalTimer($hash);
          
            return 'Interval must be greater than 0'
              unless ( $attrVal > 0 );
          
            $hash->{INTERVAL} = $attrVal;

            Log3 $name, 3, "GroheOndusSmartBridge ($name) - set interval: $attrVal";
        }
        elsif ( $cmd eq 'del' ) 
        {
            RemoveInternalTimer($hash);
            $hash->{INTERVAL} = 60;

            Log3 $name, 3, "GroheOndusSmartBridge ($name) - delete User interval and set default: 60";
        }
    }
	# Attribute "groheOndusBaseURL"
    elsif ( $attrName eq 'groheOndusBaseURL' ) 
    {
        if ( $cmd eq 'set' ) 
        {
            $hash->{URL} = $attrVal . '/v2';
        
            Log3 $name, 3, "GroheOndusSmartBridge ($name) - set groheOndusBaseURL to: $attrVal";
        }
        elsif ( $cmd eq 'del' ) 
        {
            $hash->{URL} = 'https://idp-apigw.cloud.grohe.com/v2';
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

    Log3 $name, 4, "GroheOndusSmartBridge ($name) - Notify";

	# process 'global' events
    if (
         (
           $devtype eq 'Global'
           and (
              grep /^INITIALIZED$/, @{$events} 
              or grep /^REREADCFG$/, @{$events} 
              or grep /^DEFINED.$name$/, @{$events} 
              or grep /^MODIFIED.$name$/, @{$events} 
              or grep /^ATTR.$name.groheOndusAccountEmail.+/, @{$events}
           )
         )
         or (
           $devtype eq 'GroheOndusSmartBridge'
           and (
              grep /^groheOndusAccountPassword.+/, @{$events} 
              or ReadingsVal( '$devname', 'token', '' ) eq 'none'
          )
        )
      )
    {
      getToken($hash);
    }

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
    	getDevices($hash);
    }

	# process internal events
    if (
        $devtype eq 'GroheOndusSmartBridge'
        and (
            grep /^state:.connected.to.cloud$/, @{$events} 
            or grep /^lastRequestState:.request_error$/, @{$events}
        )
      )
    {
    	# initial load of the timer on state changed to "connected to cloud"
    	# after interval 
      	InternalTimer( gettimeofday() + $hash->{INTERVAL}, "FHEM::GroheOndusSmartBridge::getDevices", $hash );
    }

    return;
}

#####################################
sub Set($@) 
{
    my ( $hash, $name, $cmd, @args ) = @_;

    Log3 $name, 4, "GroheOndusSmartBridge ($name) - Set was called cmd: $cmd";

    if ( lc $cmd eq 'getdevicesstate' ) 
    {
        getDevices($hash);
    }
    elsif ( lc $cmd eq 'gettoken' ) 
    {
        return "please set Attribut groheOndusAccountEmail first"
          if ( AttrVal( $name, 'groheOndusAccountEmail', 'none' ) eq 'none' );
    
        return "please set groheOndusAccountPassword first"
          if ( not defined( ReadPassword($hash) ) );
    
        return "token is up to date"
          if ( defined( $hash->{helper}{token} ) );

        getToken($hash);
    }
    elsif ( lc $cmd eq 'groheondusaccountpassword' ) 
    {
        return "please set Attribut groheOndusAccountEmail first"
          if ( AttrVal( $name, 'groheOndusAccountEmail', 'none' ) eq 'none' );
    
        return "usage: $cmd <password>" 
          if ( @args != 1 );

        my $passwd = join( ' ', @args );
        StorePassword( $hash, $passwd );
    }
    elsif ( lc $cmd eq 'deleteaccountpassword' ) 
    {
        return "usage: $cmd <password>" 
          if ( @args != 0 );

        DeletePassword($hash);
    }
    else 
    {
        my $list = "getDevicesState:noArg getToken:noArg"
          if ( defined( ReadPassword($hash) ) );

        $list .= " groheOndusAccountPassword"
          if ( not defined( ReadPassword($hash) ) );

        $list .= " deleteAccountPassword:noArg"
          if ( defined( ReadPassword($hash) ) );

        return "Unknown argument $cmd, choose one of $list";
    }

    return undef;
}

#####################################
# Write($hash, $payload, $deviceId, $model)
sub Write($@) 
{
    my ( $hash, $payload, $deviceId, $model ) = @_;
    my $name = $hash->{NAME};

    my ( $session_id, $header, $uri, $method );

    ( $payload, $session_id, $header, $uri, $method, $deviceId, $model ) =
      createHttpValueStrings( $hash, $payload, $deviceId, $model );

    HttpUtils_NonblockingGet(
        {
            url       => $hash->{URL} . $uri,
            timeout   => 15,
            hash      => $hash,
            device_id => $deviceId,
       		location_id => $hash->{helper}{current_location_id}, 
        	room_id => $hash->{helper}{current_room_id}, 
            data      => $payload,
            method    => $method,
            header    => $header,
            doTrigger => 1,
            callback  => \&ErrorHandling
        }
    );

     Log3($name, 4,
         "GroheOndusSmartBridge ($name) - Send with URL: $hash->{URL}$uri, HEADER: $header, DATA: $payload, METHOD: $method");
}

#####################################
sub ErrorHandling($$$) 
{
    my ( $param, $err, $data ) = @_;

    my $hash  = $param->{hash};
    my $name  = $hash->{NAME};
    my $dhash = $hash;

    $dhash = $modules{GroheOndusSmartDevice}{defptr}{ $param->{'device_id'} }
      unless ( not defined( $param->{'device_id'} ) );

    my $dname = $dhash->{NAME};

    my $decode_json = eval { decode_json($data) };
    
    if ($@) 
    {
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - JSON error while request";
    }

   #Log3($name, 5, "GroheOndusSmartBridge ($name) - Result with CODE: $param->{code} JSON: $data");

    # error
    if ( defined($err) ) 
    {
        if ( $err ne "" ) 
        {
            readingsBeginUpdate($dhash);
            
            readingsBulkUpdate( $dhash, "state", "$err" )
              if ( ReadingsVal( $dname, "state", 1 ) ne "initialized" );

            readingsBulkUpdate( $dhash, "lastRequestState", "request_error", 1 );

            if ( $err =~ /timed out/ ) 
            {
                Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: connect to grohe cloud is timed out. check network";
            }
            elsif ($err =~ /Keine Route zum Zielrechner/
                or $err =~ /no route to target/ )
            {
                Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: no route to target. bad network configuration or network is down";
            }
            else 
            {
                Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: $err";
            }

            readingsEndUpdate( $dhash, 1 );

            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: GroheOndusSmartBridge RequestErrorHandling: error while requesting grohe cloud: $err";

            delete $dhash->{helper}{deviceAction}
              if ( defined( $dhash->{helper}{deviceAction} ) );

            return;
        }
    }

    # errorhandling
    if ( $data eq "" 
    	and exists( $param->{code} ) 
    	and $param->{code} != 200 ) 
    {
        readingsBeginUpdate($dhash);
        readingsBulkUpdate( $dhash, "state", $param->{code}, 1 )
          if ( ReadingsVal( $dname, "state", 1 ) ne "initialized" );

        readingsBulkUpdateIfChanged( $dhash, "lastRequestState", "request_error", 1 );

        if ( $param->{code} == 401 
        	and $hash eq $dhash ) 
        {
            if ( ReadingsVal( $dname, 'token', 'none' ) eq 'none' ) 
            {
                readingsBulkUpdate( $dhash, "state", "no token available", 1 );
                readingsBulkUpdateIfChanged( $dhash, "lastRequestState", "no token available", 1 );
            }

            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: " . $param->{code};
        }
        elsif ( $param->{code} == 204
            and $dhash ne $hash
            and defined( $dhash->{helper}{deviceAction} ) )
        {
            readingsBulkUpdate( $dhash, "state", "the command is processed", 1 );

            InternalTimer(
                gettimeofday() + 5,
                "FHEM::GroheOndusSmartBridge::getDevices",
                $hash, 1
            );
        }
        elsif ( $param->{code} != 200 ) 
        {
            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: " . $param->{code};
        }

        readingsEndUpdate( $dhash, 1 );

        Log3 $dname, 3,
            "GroheOndusSmartBridge ($dname) - RequestERROR: received http code "
          . $param->{code}
          . " without any data after requesting grohe cloud";

        delete $dhash->{helper}{deviceAction}
          if ( defined( $dhash->{helper}{deviceAction} ) );

        return;
    }


    if (
        $data =~ /Error/
        or (    defined($decode_json)
            and ref($decode_json) eq 'HASH'
            and defined( $decode_json->{errors} ) )
      )
    {
        readingsBeginUpdate($dhash);
        
        readingsBulkUpdate( $dhash, "state", $param->{code}, 1 )
          if ( ReadingsVal( $dname, "state", 0 ) ne "initialized" );

        readingsBulkUpdate( $dhash, "lastRequestState", "request_error", 1 );

        if ( $param->{code} == 400 ) 
        {
            if ($decode_json) 
            {
                if ( ref( $decode_json->{errors} ) eq "ARRAY"
                    and defined( $decode_json->{errors} ) )
                {
                    readingsBulkUpdate(
                        $dhash,
                        "state",
                        $decode_json->{errors}[0]{error} . ' '
                          . $decode_json->{errors}[0]{attribute},
                        1
                    );
            
                    readingsBulkUpdate(
                        $dhash,
                        "lastRequestState",
                        $decode_json->{errors}[0]{error} . ' '
                          . $decode_json->{errors}[0]{attribute},
                        1
                    );
            
                    Log3 $dname, 5,
                        "GroheOndusSmartBridge ($dname) - RequestERROR: "
                      . $decode_json->{errors}[0]{error} . " "
                      . $decode_json->{errors}[0]{attribute};
                }
            }
            else 
            {
                readingsBulkUpdate( $dhash, "lastRequestState",
                    "Error 400 Bad Request", 1 );
                Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: Error 400 Bad Request";
            }
        }
        elsif ( $param->{code} == 503 ) 
        {
            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: Error 503 Service Unavailable";
            readingsBulkUpdate( $dhash, "state", "Service Unavailable", 1 );
            readingsBulkUpdate( $dhash, "lastRequestState", "Error 503 Service Unavailable", 1 );

        }
        elsif ( $param->{code} == 404 ) 
        {
            if ( defined( $dhash->{helper}{deviceAction} ) 
            	and $dhash ne $hash )
            {
                readingsBulkUpdate( $dhash, "state", "device Id not found", 1 );
                readingsBulkUpdate( $dhash, "lastRequestState", "device id not found", 1 );
            }

            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: Error 404 Not Found";
        }
        elsif ( $param->{code} == 500 ) 
        {
            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: check the ???";

        }
        else 
        {
            Log3 $dname, 5, "GroheOndusSmartBridge ($dname) - RequestERROR: http error "
              . $param->{code};
        }

        readingsEndUpdate( $dhash, 1 );

        Log3 $dname, 5,
            "GroheOndusSmartBridge ($dname) - RequestERROR: received http code "
          . $param->{code}
          . " receive Error after requesting grohe cloud";

        delete $dhash->{helper}{deviceAction}
          if ( defined( $dhash->{helper}{deviceAction} ) );

        return;
    }

	# update state -> in sub "Notify" timer is reloaded
    if ( defined( $hash->{helper}{current_location_id} ) )
	{
		# change state to "connected to cloud" -> Notify -> load timer
	    readingsBeginUpdate($hash);
   		readingsBulkUpdateIfChanged( $hash, 'state', 'connected to cloud', 1 );
	    readingsEndUpdate($hash, 1 );
	}

	# no error: process response
    ResponseProcessing( $param, $data );
}

#####################################
sub ResponseProcessing($$) 
{
    my ( $param, $json ) = @_;

    my $hash  = $param->{hash};
    my $name = $hash->{NAME};
    my $decode_json = eval { decode_json($json) };

    my $dhash = $hash;

	# get caller device: SmartBridge (me) or SmartDevice
    $dhash = $modules{GroheOndusSmartDevice}{defptr}{ $param->{'device_id'} }
      unless ( not defined( $param->{'device_id'} ) );

    my $dname = $dhash->{NAME};

    if ($@) 
    {
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 ) 
        {
            readingsBeginUpdate($hash);
            readingsBulkUpdate( $hash, 'JSON_ERROR',        $@,    1 );
            readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', $json, 1 );
            readingsEndUpdate( $hash, 1 );
        }
    }

	# token und UID 
    if ( ref($decode_json) eq 'HASH' 
    	and defined( $decode_json->{token} ) 
    	and $decode_json->{token} 
    	and defined( $decode_json->{uid} ) 
    	and $decode_json->{uid} ) 
    {
        # save values in helper       
        $hash->{helper}{token} = $decode_json->{token};
        $hash->{helper}{user_id} = $decode_json->{uid};

        # write values to readings       
        readingsSingleUpdate( $hash, 'token', $hash->{helper}{token}, 1 );
        readingsSingleUpdate( $hash, 'uid', $hash->{helper}{user_id}, 1 );

		# fetch locations
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - fetch locations";
        Write( $hash, undef, undef, 'smartbridge' );

        return;
    }
    # locations
    elsif ( ref( $decode_json ) eq "ARRAY"
        and scalar( @{ $decode_json } ) > 0
        and ref ( @{ $decode_json }[0]) eq "HASH"
        and defined( @{ $decode_json }[0]->{address} ) )
    {
    	#[
    	#	{
    	#		"id":48434,
    	#		"name":"Haus",
    	#		"type":2,
    	#		"role":"owner",
    	#		"timezone":"Europe/Berlin",
    	#		"water_cost":-1,
    	#		"energy_cost":-1,
    	#		"heating_type":-1,
    	#		"currency":"EUR",
    	#		"default_water_cost":0.004256,
    	#		"default_energy_cost":0.003977,
    	#		"default_heating_type":2,
    	#		"emergency_shutdown_enable":true,
    	#		"address":
    	#		{
    	#			"street":"Stra�e 5",
    	#			"city":"Dorf",
    	#			"zipcode":"123456",
    	#			"housenumber":"",
    	#			"country":"Deutschland",
    	#			"country_code":"DE",
    	#			"additionalInfo":""
    	#		}
    	#	}
    	#]
    	
        Log3 $name, 5, "GroheOndusSmartBridge ($name) - locations count " . scalar( @{ $decode_json } );

        foreach my $location ( @{ $decode_json } ) 
        {
        	# save current location in list
        	$hash->{helper}{location_list}{$location->{id}} =
        	{
        		'location' => encode_json( $location )
        	};
        	
            $hash->{helper}{current_location_id} = $location->{id};

            WriteReadings( $hash, $location );

	        Log3 $name, 3, "GroheOndusSmartBridge ($name) - processed location with ID " . $hash->{helper}{current_location_id};
	        Log3 $name, 5, "GroheOndusSmartBridge ($name) - processed location's DATA is " . encode_json( $hash->{helper}{location_list}{$location->{id}} );

    	    # fetch rooms within current location         
        	Write( $hash, undef, undef, 'smartbridge' );
        }

        # update reading
        readingsSingleUpdate( $hash, 'count_locations', scalar( keys %{ $hash->{helper}{location_list} } ), 0 );

        return;
    }
    # rooms
    elsif (ref( $decode_json ) eq "ARRAY"
        and scalar( @{ $decode_json } ) > 0 
        and ref ( @{ $decode_json }[0]) eq "HASH"
        and defined( @{ $decode_json }[0]->{room_type} ))
    {
    	#[
    	#	{
    	#		"id":12345,
    	#		"name":"EG K�che",
    	#		"type":0,
    	#		"room_type":15,
    	#		"role":"owner"
    	#	}
    	#]
 
        Log3 $name, 5, "GroheOndusSmartBridge ($name) - rooms count " . scalar( @{ $decode_json } );
    	
        foreach my $room ( @{ $decode_json } ) 
        {
        	# save current room in list
        	$hash->{helper}{room_list}{$room->{id}} =
        	{
        		'location_id' => $param->{'location_id'}, 
        		'room' => encode_json( $room )
        	};
       	
            $hash->{helper}{current_room_id} = $room->{id};

            WriteReadings( $hash, $room);

        	Log3 $name, 3, "GroheOndusSmartBridge ($name) - processed room with ID " . $hash->{helper}{current_room_id};
	        Log3 $name, 5, "GroheOndusSmartBridge ($name) - processed room DATA is " . encode_json( $hash->{helper}{room_list}{$room->{id}} );
          
    	    # fetch appliances within current room
	        Write( $hash, undef, undef, 'smartbridge' );
        }

        # update reading
        readingsSingleUpdate( $hash, 'count_rooms', scalar( keys %{ $hash->{helper}{room_list} } ), 0 );

        return;
    }
    # appliances
    elsif (ref( $decode_json ) eq "ARRAY"
        and scalar( @{ $decode_json } ) > 0  
        and ref ( @{ $decode_json }[0]) eq "HASH"
        and defined( @{ $decode_json }[0]->{appliance_id} ))
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
    	
        Log3 $name, 5, "GroheOndusSmartBridge ($name) - appliances count " . scalar( @{ $decode_json } );

        foreach my $appliance ( @{ $decode_json } ) 
        {
        	# save current appliance in list
        	$hash->{helper}{appliance_list}{$appliance->{appliance_id}} = 
        	{
        		location_id => $param->{'location_id'}, 
        		room_id => $param->{'room_id'},
        		appliance => encode_json( $appliance )
        	};
        	
            $hash->{helper}{current_appliance_id} = $appliance->{appliance_id};

            WriteReadings( $hash, $appliance);

	        Log3 $name, 3, "GroheOndusSmartBridge ($name) - processed appliance with ID " . $hash->{helper}{current_appliance_id};
	        Log3 $name, 5, "GroheOndusSmartBridge ($name) - processed appliance DATA is " . encode_json( $hash->{helper}{appliance_list}{$appliance->{appliance_id}} );
        }

        readingsSingleUpdate( $hash, 'count_appliance', scalar( keys %{ $hash->{helper}{appliance_list} } ), 0 );

		# autocreate of the devices
        my ( $json, $tail ) = ParseJSON( $hash, $json );

        while ($json) 
        {
            Log3 $name, 5,
                "GroheOndusSmartBridge ($name) - Decoding JSON message. Length: "
              . length($json)
              . " Content: "
              . $json;

            Log3 $name, 5,
                "GroheOndusSmartBridge ($name) - Vor Sub: Laenge JSON: "
              . length($json)
              . " Content: "
              . $json
              . " Tail: "
              . $tail;

            unless ( not defined($tail) and not($tail) ) 
            {
                $decode_json = eval { decode_json($json) };
                
                if ($@) 
                {
                    Log3 $name, 3, "GroheOndusSmartBridge ($name) - JSON error while request: $@";
                }

				# dispatch to GroheOndusSmartDevice::Parse()
                Dispatch( $hash, $json, undef );
            }

            ( $json, $tail ) = ParseJSON( $hash, $tail );

            Log3 $name, 5,
                "GroheOndusSmartBridge ($name) - Nach Sub: Laenge JSON: "
              . length($json)
              . " Content: "
              . $json
              . " Tail: "
              . $tail;
        }
      
        return;
    }
    # caller is not this SmartBridge, so dispatch to SmartDevices
    elsif ( not $hash eq $dhash )
    {
	    Log3 $name, 5, "GroheOndusSmartBridge ($name) - DISPATCHING ($dname)";

		# create data structure matching regex entry in matchlist
		my $applianceId = encode_json(
		{
   		   	'appliance_id' => $dhash->{DEVICEID},
   		   	'data' => $decode_json
		});
		
      	Dispatch( $hash, $applianceId, undef );
        return;
    }

    Log3 $name, 3, "GroheOndusSmartBridge ($name) - no Match for processing data";
}

#####################################
sub WriteReadings($$) 
{
    my ( $hash, $decode_json ) = @_;
    my $name = $hash->{NAME};

#    if ( defined( $decode_json->{id} )
#        and $decode_json->{id}
#        and defined( $decode_json->{name} )
#        and $decode_json->{name} )
#    {
#        readingsBeginUpdate($hash);
#        if ( $decode_json->{id} eq $hash->{helper}{current_location_id} ) 
#        {
#            readingsBulkUpdateIfChanged( $hash, 'name', $decode_json->{name} );
#            #readingsBulkUpdateIfChanged( $hash, 'authorized_user_ids', scalar( @{ $decode_json->{authorized_user_ids} } ) );
#            #readingsBulkUpdateIfChanged( $hash, 'devices', scalar( @{ $decode_json->{devices} } ) );
#
#            while ( ( my ( $t, $v ) ) = each %{ $decode_json->{geo_position} } )
#            {
#                $v = encode_utf8($v);
#                readingsBulkUpdateIfChanged( $hash, $t, $v );
#            }
#
#            readingsBulkUpdateIfChanged( $hash, 'zones', scalar( @{ $decode_json->{zones} } ) );
#        }
#        elsif ( $decode_json->{id} ne $hash->{helper}{current_location_id}
#            and ref( $decode_json->{model} ) eq 'ARRAY'
#            and ref( $decode_json->{model}[0]{properties} ) eq 'ARRAY' )
#        {
#            my $properties =
#              scalar( @{ $decode_json->{model}[0]{properties} } );
#
#            do 
#            {
#                while ( ( my ( $t, $v ) ) =
#                    each
#                    %{ $decode_json->{model}[0]{properties}[$properties] } )
#                {
#                    next
#                      if ( ref($v) eq 'ARRAY' );
#
#                    #$v = encode_utf8($v);
#                    readingsBulkUpdateIfChanged(
#                        $hash,
#                        $decode_json->{model}[0]{properties}[$properties]
#                          {name} . '-' . $t,
#                        $v
#                      )
#                      unless (
#                        $decode_json->{model}[0]{properties}[$properties]
#                        {name} eq 'ethernet_status'
#                        or $decode_json->{model}[0]{properties}[$properties]
#                        {name} eq 'wifi_status' );
#
#                    if (
#                        (
#                            $decode_json->{model}[0]{properties}
#                            [$properties]{name} eq 'ethernet_status'
#                            or $decode_json->{model}[0]{properties}
#                            [$properties]{name} eq 'wifi_status'
#                        )
#                        and ref($v) eq 'HASH'
#                      )
#                    {
#                        if ( $decode_json->{model}[0]{properties}
#                            [$properties]{name} eq 'ethernet_status' )
#                        {
#                            readingsBulkUpdateIfChanged( $hash, 'ethernet_status-mac', $v->{mac} );
#                            readingsBulkUpdateIfChanged( $hash, 'ethernet_status-ip', $v->{ip} )
#                              if ( ref( $v->{ip} ) ne 'HASH' );
#                              
#                            readingsBulkUpdateIfChanged( $hash, 'ethernet_status-isconnected', $v->{isconnected} );
#                        }
#                        elsif ( $decode_json->{model}[0]{properties}
#                            [$properties]{name} eq 'wifi_status' )
#                        {
#                            readingsBulkUpdateIfChanged( $hash, 'wifi_status-ssid', $v->{ssid} );
#                            readingsBulkUpdateIfChanged( $hash, 'wifi_status-mac', $v->{mac} );
#                            readingsBulkUpdateIfChanged( $hash, 'wifi_status-ip', $v->{ip} )
#                              if ( ref( $v->{ip} ) ne 'HASH' );
#                              
#                            readingsBulkUpdateIfChanged( $hash, 'wifi_status-isconnected', $v->{isconnected} );
#                            readingsBulkUpdateIfChanged( $hash, 'wifi_status-signal', $v->{signal} );
#                        }
#                    }
#                }
#                $properties--;
#
#            } while ( $properties >= 0 );
#        }
#        readingsEndUpdate( $hash, 1 );
#    }

    Log3 $name, 4, "GroheOndusSmartBridge ($name) - readings would be written";
}

#####################################
sub getDevices($) 
{
    my $hash = shift;
    my $name = $hash->{NAME};

    RemoveInternalTimer($hash);

    if ( not IsDisabled($name) ) 
    {
        Log3 $name, 4, "GroheOndusSmartBridge ($name) - fetch device list and device states";

		# clear hash for start new fetching 
	    delete $hash->{helper}{current_location_id}
    	  if ( defined( $hash->{helper}{current_location_id} )
      		and $hash->{helper}{current_location_id} );
		
        Write( $hash, undef, undef, 'smartbridge' );

	   	# reload timer
      	InternalTimer( gettimeofday() + $hash->{INTERVAL}, "FHEM::GroheOndusSmartBridge::getDevices", $hash );
    }
    else 
    {
        readingsSingleUpdate( $hash, 'state', 'disabled', 1 );
        
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - device is disabled";
    }
}

#####################################
sub getToken($) 
{
    my $hash = shift;
    my $name = $hash->{NAME};

    return readingsSingleUpdate( $hash, 'state', 'please set Attribut groheOndusAccountEmail first', 1 )
      if ( AttrVal( $name, 'groheOndusAccountEmail', 'none' ) eq 'none' );
      
    return readingsSingleUpdate( $hash, 'state', 'please set grohe account password first', 1 )
      if ( not defined( ReadPassword($hash) ) );
   
    readingsSingleUpdate( $hash, 'state', 'get token', 1 );

    delete $hash->{helper}{token}
      if ( defined( $hash->{helper}{token} )
      	and $hash->{helper}{token} );

    delete $hash->{helper}{user_id}
      if ( defined( $hash->{helper}{user_id} ) 
        and $hash->{helper}{user_id} );

    delete $hash->{helper}{current_location_id}
      if ( defined( $hash->{helper}{current_location_id} )
      	and $hash->{helper}{current_location_id} );

    Log3 $name, 3, "GroheOndusSmartBridge ($name) - send credentials to fetch Token and locationId";

    Write(
        $hash,
        '{"username": "'
          . AttrVal( $name, 'groheOndusAccountEmail', 'none' )
          . '","password": "'
          . ReadPassword($hash) . '"}',
        undef,
        'smartbridge'
    );
}

#####################################
sub StorePassword($$) 
{
    my ( $hash, $password ) = @_;
    my $index   = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
    my $key     = getUniqueId() . $index;
    my $enc_pwd = "";

    if ( eval "use Digest::MD5;1" ) 
    {
        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
    }

    for my $char ( split //, $password ) 
    {
        my $encode = chop($key);
        $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
        $key = $encode . $key;
    }

    my $err = setKeyValue( $index, $enc_pwd );
    
    return "error while saving the password - $err" 
      if ( defined($err) );

    return "password successfully saved";
}

#####################################
sub ReadPassword($) 
{
    my ($hash) = @_;
    my $name   = $hash->{NAME};
    my $index  = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
    my $key    = getUniqueId() . $index;
    my ( $password, $err );

    Log3 $name, 4, "GroheOndusSmartBridge ($name) - Read password from file";

    ( $err, $password ) = getKeyValue($index);

    if ( defined($err) ) 
    {
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - unable to read password from file: $err";
        return undef;
    }

    if ( defined($password) ) 
    {
        if ( eval "use Digest::MD5;1" ) 
        {
            $key = Digest::MD5::md5_hex( unpack "H*", $key );
            $key .= Digest::MD5::md5_hex($key);
        }

        my $dec_pwd = '';

        for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/g ) ) 
        {
            my $decode = chop($key);
            $dec_pwd .= chr( ord($char) ^ ord($decode) );
            $key = $decode . $key;
        }

        return $dec_pwd;

    }
    else 
    {
        Log3 $name, 3, "GroheOndusSmartBridge ($name) - No password in file";
        return undef;
    }
}

#####################################
sub Rename(@) 
{
    my ( $new, $old ) = @_;
    my $hash = $defs{$new};

    StorePassword( $hash, ReadPassword($hash) );
    setKeyValue( $hash->{TYPE} . "_" . $old . "_passwd", undef );

    return undef;
}

#####################################
sub ParseJSON($$) 
{
    my ( $hash, $buffer ) = @_;

    my $name  = $hash->{NAME};
    my $open  = 0;
    my $close = 0;
    my $msg   = '';
    my $tail  = '';

    if ($buffer) 
    {
        foreach my $c ( split //, $buffer ) 
        {
            if ( $open == $close 
              and $open > 0 ) 
            {
                $tail .= $c;
                Log3 $name, 5, "GroheOndusSmartBridge ($name) - $open == $close and $open > 0";
            }
            elsif ( ( $open == $close ) and ( $c ne '{' ) ) 
            {
                Log3 $name, 5, "GroheOndusSmartBridge ($name) - Garbage character before message: " . $c;
            }
            else 
            {
                if ( $c eq '{' ) 
                {
                    $open++;
                }
                elsif ( $c eq '}' ) 
                {
                    $close++;
                }

                $msg .= $c;
            }
        }

        if ( $open != $close ) 
        {
            $tail = $msg;
            $msg  = '';
        }
    }

    Log3 $name, 5, "GroheOndusSmartBridge ($name) - return msg: $msg and tail: $tail";
    return ( $msg, $tail );
}

#####################################
# createHttpValueStrings($hash, $payload, $deviceId, $model)
# return ($payload, $session_id, $header, $uri, $method, $deviceId, $model)
sub createHttpValueStrings($@) 
{
    my ( $hash, $payload, $deviceId, $model ) = @_;

    my $session_id = $hash->{helper}{token};
    my $name  = $hash->{NAME};
    my $header     = "Content-Type: application/json";
    my $uri        = '';
    my $method     = 'POST';
    
    my $device_locationId;
    my $device_roomId;

   	# get locationId and roomId for the device from table
    if( defined( $deviceId )
      and defined( $hash->{helper}{appliance_list} )
      and defined( $hash->{helper}{appliance_list}{$deviceId} ) ) 
    {
       	my $record = $hash->{helper}{appliance_list}{$deviceId};
       	$device_locationId = $record->{location_id};
       	$device_roomId = $record->{room_id};
       	
       	Log3 $name, 5, "GroheOndusSmartBridge ($name) - got LocationId " . $device_locationId . " RoomId " . $device_roomId;
    }

	# if there is a token, put it in header
    if ( defined( $hash->{helper}{token} ) )
    {
    	$header .= "\nAuthorization: $session_id"
    }
    # there is no token, so login
    else
    {
    	# call from getToken -> payload = username + password
    	$uri .= '/iot/auth/users/login'; 

	    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
    }
    
    # set default for payload
    if ( not defined($payload) ) 
    {
    	# empty payload
    	$payload = '{}'; 
    }

    if ( defined($model) ) 
    {
	    ### smartbridge
    	if( $model eq 'smartbridge' )
    	{
		    # empty payload -> get location, get rooms, get devices
    		if ( $payload eq '{}' ) 
		    {
		        $method = 'GET';
        
		        # current_location_id not defined yet -> extend URL
		        if ( not defined( $hash->{helper}{current_location_id} ) )
		        {
		        	$uri .= 
		        	  '/iot/locations';
          
          			# update state
		        	readingsSingleUpdate( $hash, 'state', 'fetch locations', 1 );

					# clear hash for fetching rooms
					if( defined( $hash->{helper}{current_room_id} ) )
					{
						delete $hash->{helper}{current_room_id};
					}

				    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
		        }
         
		        # current_room_id not defined yet -> extend URL
		        elsif ( defined( $hash->{helper}{current_location_id} )
		        	and not defined( $hash->{helper}{current_room_id} ) )
		        {
        			$uri .= 
        			  '/iot/locations/' . 
        			  $hash->{helper}{current_location_id} . 
        			  '/rooms';

          			# update state
        			readingsSingleUpdate( $hash, 'state', 'fetch rooms', 1 );

					# clear hash for fetching appliances
					if( defined( $hash->{helper}{current_appliance_id} ) )
					{
						delete $hash->{helper}{current_appliance_id};
					}

				    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
        		}
        
		        # current_appliance_id not defined yet -> extend URL
        		elsif ( defined( $hash->{helper}{current_location_id} )
		            and defined( $hash->{helper}{current_room_id} )
        		    and not defined( $hash->{helper}{current_appliance_id} ) )
		        {
        			$uri .= 
        			  '/iot/locations/' . 
        			  $hash->{helper}{current_location_id} . 
        			  '/rooms/' . 
        			  $hash->{helper}{current_room_id} . 
        			  '/appliances';

          			# update state
		        	readingsSingleUpdate( $hash, 'state', 'fetch appliances', 1 );
				
				    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
        		}
    		}
    	}
	    ### sense_guard
        elsif ( $model eq 'sense_guard' 
          and defined( $device_locationId )
          and defined( $device_roomId ) ) 
        {
            my $dhash = $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

			my $currentPayload = $payload;
			
            $method = $currentPayload->{method};
            $payload = $currentPayload->{payload};
       
   			$uri .= 
   				'/iot/locations/' . 
   				$device_locationId . 
   				'/rooms/' . 
   				$device_roomId . 
   				'/appliances/' .
   				$deviceId .
   				$currentPayload->{URI};

		    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
        }
	    ### sense
        elsif ( $model eq 'sense'  
          and defined( $device_locationId )
          and defined( $device_roomId ) )
        {
            my $dhash = $modules{GroheOndusSmartDevice}{defptr}{$deviceId};
       
			my $currentPayload = $payload;
			
            $method = $currentPayload->{method};
            $payload = $currentPayload->{payload};
       
   			$uri .= 
   				'/iot/locations/' . 
   				$device_locationId . 
   				'/rooms/' . 
   				$device_roomId . 
   				'/appliances/' .
   				$deviceId .
   				$currentPayload->{URI};

		    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
        }
    }
    else
    {
    	$model = "unknown";
    }
	
   	Log3 $name, 3, "GroheOndusSmartBridge ($name) - no match - Model: " . $model . " URI " . $uri;

    return ( $payload, $session_id, $header, $uri, $method, $deviceId, $model );
}

#####################################
sub DeletePassword($) 
{
    my $hash = shift;

    setKeyValue( $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd", undef );

    return undef;
}

1;

=pod

=item device
=item summary       Modul to communicate with the GroheCloud
=item summary_DE    Modul zur Datenübertragung zur GroheCloud

=begin html

<a name="GroheOndusSmartBridge"></a>
<h3>GroheOndusSmartBridge</h3>
<ul>
  <u><b>Prerequisite</b></u>
  <br><br>
  <li>In combination with GroheOndusSmartDevice this FHEM Module controls the communication between the GroheOndusCloud and connected Devices like Grohe Sense and Grohe SenseGUARD</li>
  <li>Installation of the following packages: apt-get install libio-socket-ssl-perl</li>
  <li>All connected Devices must be correctly installed in the GroheOndusAPP</li>
</ul>
<br>
<a name="GroheOndusSmartBridgedefine"></a>
<b>Define</b>
<ul><br>
  <code>define &lt;name&gt; GroheOndusSmartBridge</code>
  <br><br>
  Example:
  <ul><br>
    <code>define GroheOndus_Bridge GroheOndusSmartBridge</code><br>
  </ul>
  <br>
  The GroheOndusSmartBridge device is created in the room GroheOndusSmart, then the devices of Your system are recognized automatically and created in FHEM. From now on the devices can be controlled and changes in the GroheOndusAPP are synchronized with the state and readings of the devices.
  <br><br>
  <a name="GroheOndusSmartBridgereadings"></a>
  <br><br>
  <b>Readings</b>
  <ul>
    <li>state - State of the Bridge</li>
    <li>token - SessionID</li>
  </ul>
  <br><br>
  <a name="GroheOndusSmartBridgeset"></a>
  <b>set</b>
  <ul>
    <li>getDeviceState - Starts a Datarequest</li>
    <li>getToken - Gets a new Session-ID</li>
    <li>groheOndusAccountPassword - Passwort which was used in the GroheOndusAPP</li>
    <li>deleteAccountPassword - delete the password from store</li>
  </ul>
  <br><br>
  <a name="GroheOndusSmartBridgeattributes"></a>
  <b>Attributes</b>
  <ul>
    <li>debugJSON - </li>
    <li>disable - Disables the Bridge</li>
    <li>interval - Interval in seconds (Default=60)</li>
    <li>groheOndusAccountEmail - Email Adresse which was used in the GroheOndusAPP</li>
  </ul>
</ul>

=end html
=begin html_DE

<a name="GroheOndusSmartBridge"></a>
<h3>GroheOndusSmartBridge</h3>
<ul>
  <u><b>Voraussetzungen</b></u>
  <br><br>
  <li>Zusammen mit dem Device GroheOndusSmartDevice stellt dieses FHEM Modul die Kommunikation zwischen der GroheOndusCloud und Fhem her. Es k&ouml;nnen damit Grohe Sense und Grohe SenseGUARD überwacht und gesteuert werden</li>
  <li>Das Perl-Modul "SSL Packet" wird ben&ouml;tigt.</li>
  <li>Unter Debian (basierten) System, kann dies mittels "apt-get install libio-socket-ssl-perl" installiert werden.</li>
  <li>Alle verbundenen Ger&auml;te und Sensoren m&uuml;ssen vorab in der GroheOndusApp eingerichtet sein.</li>
</ul>
<br>
<a name="GroheOndusSmartBridgedefine"></a>
<b>Define</b>
<ul><br>
  <code>define &lt;name&gt; GroheOndusSmartBridge</code>
  <br><br>
  Beispiel:
  <ul><br>
    <code>define GroheOndus_Bridge GroheOndusSmartBridge</code><br>
  </ul>
  <br>
  Das Bridge Device wird im Raum GroheOndusSmart angelegt und danach erfolgt das Einlesen und automatische Anlegen der Ger&auml;te. Von nun an k&ouml;nnen die eingebundenen Ger&auml;te gesteuert werden. &Auml;nderungen in der APP werden mit den Readings und dem Status syncronisiert.
  <br><br>
  <a name="GroheOndusSmartBridgereadings"></a>
  <br><br>
  <b>Readings</b>
  <ul>
    <li>state - Status der Bridge</li>
    <li>token - SessionID</li>
  </ul>
  <br><br>
  <a name="GroheOndusSmartBridgeset"></a>
  <b>set</b>
  <ul>
    <li>getDeviceState - Startet eine Abfrage der Daten.</li>
    <li>getToken - Holt eine neue Session-ID</li>
    <li>groheOndusAccountPassword - Passwort, welches in der GroheOndusApp verwendet wurde</li>
    <li>deleteAccountPassword - l&oml;scht das Passwort aus dem Passwortstore</li>
  </ul>
  <br><br>
  <a name="GroheOndusSmartBridgeattributes"></a>
  <b>Attribute</b>
  <ul>
    <li>debugJSON - JSON Fehlermeldungen</li>
    <li>disable - Schaltet die Datenübertragung der Bridge ab</li>
    <li>interval - Abfrageinterval in Sekunden (default: 300)</li>
    <li>groheOndusAccountEmail - Email Adresse, die auch in der GroheOndusApp verwendet wurde</li>
  </ul>
</ul>

=end html_DE

=for :application/json;q=META.json 73_GroheOndusSmartBridge.pm
{
  "abstract": "Modul to communicate with the GroheCloud",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Datenübertragung zur GroheCloud"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "Grohe",
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
        "IO::Socket::SSL": 0,
        "JSON": 0,
        "HttpUtils": 0,
        "Encode": 0
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
