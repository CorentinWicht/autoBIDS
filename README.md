# autoBIDS

## Description:
LNS automated MATLAB script for EEG data BIDS generation using EEGLAB BIDS plugin XXX

Flexible and adaptable to all designs and folder trees.

All steps can be skiped. All default values can be modified.

A log is generated after each run to explain what was done to the files.

For more information on how to get started, please refer to the **[Wiki user manual](https://github.com/CorentinWicht/autoERP2.0/wiki)**.

**⚠️ Currently only compatible with raw .bdf (BioSemi) files**


## Dependencies
| PLUGINS | Description |
| ------ | ------ |
| [EEGLAB v2021.0](https://github.com/sccn/eeglab) | Main software that manages most of the preprocessing and analyses toolboxes described in the table below |
| [BLINKER v1.1.2](http://vislab.github.io/EEG-Blinks/) | BLINKER  is an automated pipeline for detecting eye blinks in EEG and calculating various properties of these blinks | 
| [CleanLine v2.0](https://github.com/sccn/cleanline) | This plugin adaptively estimates and removes sinusoidal (e.g. line) noise from your ICA components or scalp channels using multi-tapering and a Thompson F-statistic |
| [Clean_rawdata v2.3](https://github.com/sccn/clean_rawdata)| This plugin is used solely for the vis_artifacts.m function for the ICA script |
|[ICLabel v1.3](https://github.com/sccn/ICLabel)|An automatic EEG independent component classifer plugin |
|[EEGInterp](https://d-nb.info/1175873608/34)| Homemade function to compute multiquadric interpolation based on radial basis function |

Isolated functions:
* [saveeph](https://sites.google.com/site/cartoolcommunity/files)
* [natsort](https://ch.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort)

The dependencies are already included in the Functions folder and loaded automatically.

## Authors
[**Corentin Aurèle Wicht, MSc**](https://www.researchgate.net/profile/Wicht_Corentin)\
*SNSF Doc.CH PhD student*\
*corentin.wicht@unifr.ch, corentinw.lcns@gmail.com*\
*[Laboratory for Neurorehabilitation Science](https://www3.unifr.ch/med/spierer/en/)*\
*University of Fribourg, Switzerland*

[**Michael Mouthon, PhD**](https://www.unifr.ch/med/annoni/en/group/team/people/3229/6a825)\
*Laboratory Engineer*\
*michael.mouthon@unifr.ch*\
*[Laboratory for Cognitive and Neurological Sciences ](https://www.unifr.ch/med/annoni/en/)*\
*University of Fribourg, Switzerland*


## Cite the repository
C.A. Wicht, M. Mouthon, autoERP2.0, (2021), GitHub repository https://github.com/HugoNjb/autoERP \
[![DOI] XXX NEED TO CREATE A DOI! 

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/">Creative Commons Attribution-NonCommercial 4.0 International License</a>.

See the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments: 
[PD Dr. Lucas Spierer](https://www.researchgate.net/profile/Lucas_Spierer) from the University of Fribourg provided substantial support and advices regarding theoretical conceptualization as well as access to the workplace and the infrastructure required to successfully complete the project.

## Fundings
This project was supported by a grant from the Velux Foundation (Grant #1078 to LS); from the Swiss National Science Foundation (Grant #320030_175469 to LS); and from the Research Pool of the University of Fribourg to PD Dr. Lucas Spierer.
