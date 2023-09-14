INSTRUCTIONS BEFORE RUNNING

~~~ PRIOR TO USING SCRIPT

1) On Flywheel, generate API key
2) Define variable FLYWHEELAPI_KEY in startup script (e.g., .zshrc)
3) Download Flywheel SDK:
https://docs.flywheel.io/hc/en-us/articles/360042106633-Upgrading-the-Python-and-MATLAB-SDK#h_48619809-ae02-427d-82c2-0e4cfe8ef405
4) Set up in MATLAB:
toolboxFile = '/path/flywheel-sdk-15.8.0.mltbx';
InstalledToolbox = matlab.addons.toolbox.installToolbox(toolboxFile)

Dependencies (please ensure all are added to home directory): 
dcm2bids specific version https://github.com/UNFmontreal/Dcm2Bids/pull/260
dcm2niix latest version https://github.com/rordenlab/dcm2niix
bids-validator latest version: https://github.com/bids-standard/bids-validator
pydeface latest version: https://github.com/poldracklab/pydeface

NOTE: config file must be updated according to your experiment. Tested on two particular datasets.

~~~ TO RUN THE SCRIPT REGULARLY

Launch matlab from the command line (not the GUI)
In shell: 
$ matlab
Then run this script

Or run script via command line.
