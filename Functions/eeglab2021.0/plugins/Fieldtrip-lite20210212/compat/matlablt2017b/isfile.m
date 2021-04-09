function [varargout] = isfile(varargin)

%ISFILE Determine if the input points to a file
%   TF = ISFILE(INPUT) returns true if INPUT points to a file and false otherwise.
%
% This is a compatibility function that should only be added to the path on
% MATLAB versions prior to R2017b. Note that currently this function only allows
% for a single string in the input, as opposed to the isfile function from MATLAB,
% which allows for multiple inputs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% try to automatically remove incorrect compat folders from the path, see https://github.com/fieldtrip/fieldtrip/issues/899

if isempty(strfind(mfilename('fullpath'), matlabroot))
  % automatic cleanup does not work when FieldTrip is installed inside the MATLAB path, see https://github.com/fieldtrip/fieldtrip/issues/1527
  
  alternatives = which(mfilename, '-all');
  if ~iscell(alternatives)
    % this is needed for octave, see https://github.com/fieldtrip/fieldtrip/pull/1171
    alternatives = {alternatives};
  end
  
  keep = true(size(alternatives));
  for i=1:numel(alternatives)
    keep(i) = keep(i) && ~any(alternatives{i}=='@');  % exclude methods from classes
    keep(i) = keep(i) && alternatives{i}(end)~='p';   % exclude precompiled files
  end
  alternatives = alternatives(keep);
  
  if exist(mfilename, 'builtin') || any(strncmp(alternatives, matlabroot, length(matlabroot)) & cellfun(@isempty, strfind(alternatives, fullfile('private', mfilename))))
    % remove this directory from the path
    p = fileparts(mfilename('fullpath'));
    warning('removing "%s" from your path, see http://bit.ly/2SPPjUS', p);
    rmpath(p);
    % call the original MATLAB function
    if exist(mfilename, 'builtin')
      [varargout{1:nargout}] = builtin(mfilename, varargin{:});
    else
      [varargout{1:nargout}] = feval(mfilename, varargin{:});
    end
    return
  end
  
end % automatic cleanup of compat directories

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this is where the actual replacement code starts
% function tf = isfile(input)

% deal with the input arguments
if nargin==1
  [input] = deal(varargin{1:1});
else
  error('incorrect number of input arguments')
end

tf = ismember(exist(input),[2 3 4 5 6]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% deal with the output arguments

varargout = {tf};
