#!rsc by RouterOS
# RouterOS script: mode-button
# Copyright (c) 2018-2025 Christian Hesse <mail@eworm.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# requires RouterOS, version=7.14
#
# act on multiple mode and reset button presses
# https://git.eworm.de/cgit/routeros-scripts/about/doc/mode-button.md

:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:local ExitOK false;
:do {
  :local ScriptName [ :jobname ];

  :global ModeButton;

  :global LogPrint;

  :set ($ModeButton->"count") ($ModeButton->"count" + 1);

  :local Scheduler [ /system/scheduler/find where name="_ModeButtonScheduler" ];

  :if ([ :len $Scheduler ] = 0) do={
    $LogPrint info $ScriptName ("Creating scheduler _ModeButtonScheduler, counting presses...");
    :global ModeButtonScheduler do={ :do {
      :local FuncName $0;

      :global ModeButton;

      :global LogPrint;
      :global ModeButtonScheduler;
      :global ValidateSyntax;

      :local LEDInvert do={
        :global ModeButtonLED;

        :global IfThenElse;

        :local LED [ /system/leds/find where leds=$ModeButtonLED \
            !disabled type~"^(on|off)\$" interface=[] ];
        :if ([ :len $LED ] = 0) do={
          :return false;
        }
        /system/leds/set type=[ $IfThenElse ([ get $LED type ] = "on") "off" "on" ] $LED;
      }

      :local Count ($ModeButton->"count");
      :local Code ($ModeButton->[ :tostr $Count ]);

      :set ($ModeButton->"count") 0;
      :set ModeButtonScheduler;
      /system/scheduler/remove [ find where name="_ModeButtonScheduler" ];

      :if ([ :len $Code ] > 0) do={
        :if ([ $ValidateSyntax $Code ] = true) do={
          $LogPrint info $FuncName ("Acting on " . $Count . " mode-button presses: " . $Code);

          :for I from=1 to=$Count do={
            $LEDInvert;
            :if ([ /system/routerboard/settings/get silent-boot ] = false) do={
              :beep length=200ms;
            }
            :delay 200ms;
            $LEDInvert;
            :delay 200ms;
          }

          :do {
            [ :parse $Code ];
          } on-error={
            $LogPrint warning $FuncName \
                ("The code for " . $Count . " mode-button presses failed with runtime error!");
          }
        } else={
          $LogPrint warning $FuncName \
              ("The code for " . $Count . " mode-button presses failed syntax validation!");
        }
      } else={
        $LogPrint info $FuncName ("No action defined for " . $Count . " mode-button presses.");
      }
    } on-error={
      :global ExitError; $ExitError false $0;
    } }
    /system/scheduler/add name="_ModeButtonScheduler" \
        on-event=":global ModeButtonScheduler; \$ModeButtonScheduler;" interval=3s;
  } else={
    $LogPrint debug $ScriptName ("Updating scheduler _ModeButtonScheduler...");
    /system/scheduler/set $Scheduler start-time=[ /system/clock/get time ];
  }
} on-error={
  :global ExitError; $ExitError $ExitOK [ :jobname ];
}
