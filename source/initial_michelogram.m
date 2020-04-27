function coincidences = initial_michelogram(options, coincidences, type, varargin)
%% Form initial raw Michelograms
% Forms the initial raw Michelograms from the raw list-mode data. I.e. a
% Michelogram without any spanning yet applied. Used by form_sinograms in
% forming the actual sinograms.
%
% INPUTS:
%   options = Machine properties.
%   coincidences = A cell matrix containing the raw data for each time
%   step. The cell matrix contains n vectors, where n is the number of time
%   steps (i.e. options.partitions). The size of the (sparse) vectors is
%   the lower triangular part of a options.detectors x  options.detectors
%   matrix, with the diagonal included.
%   type = The type of input data (trues, randoms, scatter, delayes or
%   prompts)
%
% OUTPUT:
%   coincidences = A cell matrix containing the raw Michelogram for each
%   time step. The cell matrix has a size of rings x rings, where each cell
%   element contains the the coincidences between the ring in x-direction
%   and ring in y-direction. E.g. coincidences{2,4} contains coincidences
%   between rings 2 and 4. Each cell element contains a vector that is the
%   lower triangular part of options.det_per_ring x options.det_per_ring
%   sized matrix.
%
% See also form_sinograms, load_data, sinogram_coordinates_2D

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright (C) 2020 Ville-Veikko Wettenhovi
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program. If not, see <https://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


pseudot = options.pseudot;

if nargin > 3
    skip = true;
else
    skip = false;
end

temp = pseudot;
pseudo_d = [];
rings = options.rings;
if ~isempty(temp) && sum(temp) > 0
    rings = rings - options.pseudot;
    for kk = 1 : temp
        pseudot(kk) = (options.cryst_per_block + 1) * kk;
    end
end
if options.det_w_pseudo > options.det_per_ring
    pseudo_d = (options.cryst_per_block+1:options.cryst_per_block+1:options.det_w_pseudo)';
end

% Forms a raw Michelogram that is still in the detector space
[~, ~, xp, yp] = detector_coordinates(options);
[~, ~, ~, ~, ~, swap] = sinogram_coordinates_2D(options, xp, yp);
if ~skip
    koko = options.det_per_ring*rings;
    if ispc
        [~,sys] = memory;
        mem = sys.PhysicalMemory.Total / 1024;
    else
        [~,w] = unix('free | grep Mem');
        stats = str2double(regexp(w, '[0-9]*', 'match'));
        mem = stats(1);
    end
    if koko*koko*2 <= (mem - mem * .3) * 1024
        L = uint32(find(tril(true(koko,koko), 0)));
    end
end
for llo=1:options.partitions
    if ~skip
        if koko*koko*2 > (mem - mem * .3) * 1024
            kk = 1;
            I = zeros(nnz(coincidences{llo}),1);
            J = zeros(nnz(coincidences{llo}),1);
            V = nonzeros(coincidences{llo});
            K = find(coincidences{llo});
            temp = 0;
            for i = 1:koko
                for j = i:koko
                    temp = temp + 1;
                    if K(kk) == temp
                        J(kk) = i;
                        I(kk) = j;
                        kk = kk + 1;
                        if kk > nnz(coincidences{llo})
                            break;
                        end
                    end
                end
                if kk > nnz(coincidences{llo})
                    break;
                end
            end
        else
            V = nonzeros(coincidences{llo});
            K = find(coincidences{llo});
            
            [I,J] = ind2sub([koko koko], L(K));
            if llo == options.partitions
                clear L
            end
        end
        prompt = sparse(I,J,V,koko,koko);
        clear I J V
    else
        if iscell(coincidences)
            prompt = coincidences{llo};
        else
            prompt = coincidences;
        end
    end
    
    eka=1;
    ll = 1;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    P1 = cell(rings + length(pseudot),(rings + length(pseudot) - eka + 1));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    for ring = eka:options.rings % Ring at a time
                
        for luuppi = 1:(rings-eka+1)-(ring-1) % All the LORs with other options.rings as well
            if luuppi == 1 % Both of the detectors are on the same ring
                % If pseudo ring then place the measurements to the next
                % ring
                if ismember(ll,pseudot)
                    ll = ll + 1;
                end
                lk = ll + 1;
                % Observations equaling the ones detected on the current
                % ring
                temppiP = full(prompt((1+options.det_per_ring*(ring-1)):(options.det_per_ring+options.det_per_ring*(ring-1)),1+options.det_per_ring*(ring-1):...
                    (options.det_per_ring+options.det_per_ring*(ring-1))));
                if sum(pseudo_d) > 0
                    for jj = 1 : numel(pseudo_d)
                        temppiP = [temppiP(1 : pseudo_d(jj) - 1, :); zeros(1,size(temppiP,2)); temppiP(pseudo_d(jj) : end, :)];
                        temppiP = [temppiP(:, 1 : pseudo_d(jj) - 1), zeros(size(temppiP,1),1), temppiP(:, pseudo_d(jj) : end)];
                    end
                end
                % combine same LORs, but with different detector order
                % (i.e. combine values at [325 25100] and [25100 325])
                temppiP = full(temppiP(tril(logical(true(options.det_w_pseudo)),0))); % Finally take only the other side
                
                if options.partitions > 1
                    P1{ll,ll} = sparse(double(temppiP(:)));
                else
                    P1{ll,ll} = uint16(temppiP(:));
                end
                
            else % Detectors on different rings
                if ismember(lk,pseudot)
                    lk = lk + 1;
                end
                temppiP2 = (prompt(1+options.det_per_ring*(ring-1)+options.det_per_ring*(luuppi-1):...
                    (options.det_per_ring+options.det_per_ring*(ring-1)+options.det_per_ring*(luuppi-1)),(1+options.det_per_ring*(ring-1)):...
                    (options.det_per_ring+options.det_per_ring*(ring-1))));
                
                if sum(pseudo_d) > 0
                    for jj = 1 : numel(pseudo_d)
                        temppiP2 = [temppiP2(1 : pseudo_d(jj) - 1, :); zeros(1,size(temppiP2,2)); temppiP2(pseudo_d(jj) : end, :)];
                        temppiP2 = [temppiP2(:, 1 : pseudo_d(jj) - 1), zeros(size(temppiP2,1),1), temppiP2(:, pseudo_d(jj) : end)];
                    end
                end
                % Combine LORs
                temppiP = double(full(triu(temppiP2)));
                temppiP2 = double(full(tril(temppiP2)));
                
                temppiP3 = temppiP;
                
                % Swap corners
                temppiP4 = zeros(size(temppiP2),'double');
                temppiP4(swap(:,:,3)) = temppiP2(swap(:,:,3));
                temppiP(swap(:,:,1)) = 0;
                temppiP = temppiP + temppiP4';
                temppiP4 = zeros(size(temppiP2),'double');
                temppiP4(swap(:,:,4)) = temppiP2(swap(:,:,4));
                temppiP(swap(:,:,2)) = 0;
                temppiP = temppiP + temppiP4';
                temppiP = temppiP';
                
                temppiP4 = zeros(size(temppiP3),'double');
                temppiP4(swap(:,:,1)) = temppiP3(swap(:,:,1));
                temppiP2(swap(:,:,3)) = 0;
                temppiP2 = temppiP2 + temppiP4';
                temppiP4 = zeros(size(temppiP3),'double');
                temppiP4(swap(:,:,2)) = temppiP3(swap(:,:,2));
                temppiP2(swap(:,:,4)) = 0;
                temppiP2 = temppiP2 + temppiP4';
                
                % Take only the other side
                temppiP2 = temppiP2(tril(true(options.det_w_pseudo),0));
                temppiP = temppiP(tril(true(options.det_w_pseudo),0));
                
                if options.partitions > 1
                    P1{ll,lk} = sparse(temppiP(:));
                    P1{lk,ll} = sparse(temppiP2(:));
                else
                    P1{ll,lk} = uint16(temppiP(:));
                    P1{lk,ll} = uint16(temppiP2(:));
                end
                lk = lk + 1;
            end
        end
        ll = ll + 1;
    end
    clear prompt
    if options.partitions > 1
        P1(cellfun(@isempty,P1)) = {sparse(size(temppiP))};
    else
        P1(cellfun(@isempty,P1)) = {zeros(size(temppiP),'uint16')};
    end
    if ~skip
        coincidences{llo} = P1;
    else
        if iscell(coincidences)
            coincidences{llo} = P1;
        else
            coincidences = P1;
        end
    end
    
    if options.verbose
        disp(['Initial Michelogram for timestep ' num2str(llo) ' formed ' '(' type ')'])
    end
    
end