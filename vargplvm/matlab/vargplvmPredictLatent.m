function [x_star_all, varx_star_all, mini] = ...
    vargplvmPredictLatent(model, Yts, testInd, batchMode, iters, displayTestOpt, mini)

% VARGPLVMPREDICTLATENT Given output observation(s) compute the approximate
% posterior
% DESC Given an output observed test point y* (or set of test points Y*)
% compute the approximate posterior p(X* | Y*) for the corresponding latent
% points.
%
% ARG model: The trained vargplvm model
% ARG Yts: The set of outputs observations
% ARG testInd: The indices of Yts to do inference for (default: all)
% ARG batchMode: If set to true, then if N* points are given in Yts, only
% one optimisation will be done in the N*-dimensional space. Otherwise, N*
% 1-dimensional optimisations will be performed. Batch mode is faster but
% possibly less accurate.
% ARG iters: the number of test iterations for the optimisation(s)
% ARG displayTestOpt: If set to true, then the test iterations will be
% displayed
% ARG mini: The indices of the points in the test set for which the test
% latent points are initialised with, ie x*(i,:) will be initialised with
% Xtrain(mini(i), :). If this vector is not given then this vector is
% computed here in the default way.
%
%
% SEEALSO: 
%
% COPYRIGHT : Andreas C. Damianou, 2013
%
% VARGPLVM

if nargin < 2 || isempty(model) || isempty(Yts), error('At least 2 arguments needed!'); end
if nargin < 3 || isempty(testInd), testInd = 1:size(Yts,1); end
if nargin < 4 || isempty(batchMode), batchMode = false; end
if nargin < 5 || isempty(iters), iters = model.globalOpt.reconstrIters; end
if nargin < 6 || isempty(displayTestOpt), displayTestOpt = false; end
if nargin < 7, mini = []; end

miniGiven = ~isempty(mini);

if batchMode
    y_star = Yts(testInd,:);
    if ~miniGiven
        mini = NaN(1,length(testInd));
        for i=1:length(testInd)
             dst = dist2(y_star(i,:), model.y);
            [~, mini(i)] = min(dst);
        end
    end
    model.mini = mini;
    vardistx = vardistCreate(model.vardist.means(mini, :), model.q, 'gaussian');
    vardistx.covars = model.vardist.covars(mini, :);
    model.vardistx = vardistx;
    [x_star_all, varx_star_all] = vargplvmOptimisePoint(model, vardistx, y_star, true, iters);
else
    x_star_all = zeros(length(testInd), model.q);
    varx_star_all = zeros(length(testInd), model.q);
    if ~miniGiven
        mini = NaN(1,length(testInd));
    end
    pb = myProgressBar(length(testInd), min(length(testInd),20));
    for i=1:length(testInd)
        pb = myProgressBar(pb,i);
        curInd = testInd(i);
        y_star = Yts(curInd,:);
        if ~miniGiven
            dst = dist2(y_star, model.y);
            [~, mini(i)] = min(dst);
        end
        model.mini = mini(i);
        vardistx = vardistCreate(model.vardist.means(mini(i),:), model.q, 'gaussian');
        vardistx.covars = model.vardist.covars(mini(i),:);
        model.vardistx = vardistx;
        
        % Find p(X_* | Y_*) which is approximated by q(X_*)
        [x_star, varx_star] = vargplvmOptimisePoint(model, vardistx, y_star, displayTestOpt, iters);
        x_star_all(i,:) = x_star;
        varx_star_all(i,:) = varx_star;
    end
    fprintf(1, '\n');
end