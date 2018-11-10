%% Load data
    % ...
    load data/Han_20171116_COactpas_TDjoined.mat

    % Run your models or whatever here, and add the resulting signals to trial_data
    % trial_data.lfads_S1 = ...

%% Process trial data
    % split into trials
    td = splitTD(...
        trial_data,...
        struct(...
            'split_idx_name','idx_startTime',...
            'linked_fields',{{...
                'target_direction',...
                'trial_id',...
                'result',...
                'bumpDir',...
                'ctrHold',...
                'ctrHoldBump'}},...
            'start_name','idx_startTime',...
            'end_name','idx_endTime'));
    
    % only get reward trials
    [~,td] = getTDidx(td,'result','R');

    % calculate movement onset
    td = getMoveOnsetAndPeak(td,struct('start_idx','idx_goCueTime','end_idx','idx_endTime','method','peak','min_ds',1));

    % bin tds (if you want 50 ms bins, uncomment below
    % td = binTD(td,5);

    % smooth signals at 50 ms kernel (also calculates firing rates instead of spike count)
    % td = smoothSignals(td,struct('signals',{{'S1_spikes'}},'calc_rate',true,'kernel_SD',0.05));

    % Separate into active and passive groups and trim
    num_bins_before = 15;
    
    % prep td_act
    [~,td_act] = getTDidx(td,'ctrHoldBump',false);
    % have to zero pad this because one trial is too short...
    td_act = trimTD(td_act,struct(...
        'idx_start',{{'idx_movement_on',-num_bins_before}},...
        'idx_end',{{'idx_movement_on',num_bins_before*2-1}},...
        'zero_pad',true));
    % clean nans out (sometimes there are nan target directions...probably bad databurst on that trial
    nanners = isnan(cat(1,td_act.target_direction));
    td_act = td_act(~nanners);
    
    % prep td_pas
    [~,td_pas] = getTDidx(td,'ctrHoldBump',true);
    td_pas = trimTD(td_pas,{'idx_bumpTime',-num_bins_before},{'idx_bumpTime',num_bins_before*2-1});
    % move bumpDir into target_direction for passive td
    if floor(td_pas(1).bumpDir) == td_pas(1).bumpDir
        % probably in degrees
        multiplier = pi/180;
    else
        warning('bumpDir may be in radians')
        multiplier = 1;
    end
    for trial = 1:length(td_pas)
        td_pas(trial).target_direction = td_pas(trial).bumpDir*multiplier;
    end

    % even out sizes
    minsize = min(length(td_act),length(td_pas));
    td_act = td_act(1:minsize);
    td_pas = td_pas(1:minsize);
    
    % Average trials by condition
    td_act_avg = trialAverage(td_act,'target_direction');
    td_pas_avg = trialAverage(td_pas,'target_direction');

    num_dirs = length(td_act_avg);

%% make the figure
    cm_viridis = viridis(200);

    signal_name = 'S1_spikes'; % or 'lfads_S1'...
    
    figure('defaultaxesfontsize',18)
    binvec = (0:num_bins_before:num_bins_before*3);
    timevec = (binvec-num_bins_before)*td(1).bin_size*1000;
    for trialnum = 1:num_dirs
        fullraster = [[td_act_avg.(signal_name)],...
            [td_pas_avg.(signal_name)]];
        clim = [min(min(fullraster)) max(max(fullraster))];
        % figure(h{trialnum})
        % plot active
        raster = td_act_avg(trialnum).(signal_name)';
        subplot(num_dirs,2,2*(trialnum-1)+1)
        imagesc(raster,clim);
        hold on
        plot([1 1]*num_bins_before,[0 size(raster,1)+1],'--w','linewidth',3)
        plot([1 1]*(num_bins_before+15),[0 size(raster,1)+1],'--w','linewidth',3)
        hold off
        set(gca,...
            'box','off',...
            'tickdir','out',...
            'xtick',binvec,...
            'xticklabel',timevec,...
            'ytick',[]);
        % xlabel('Time after movement onset (ms)')
        % ylabel('Neuron')
        ylabel(sprintf('Target Direction: %f',td_act_avg(trialnum).target_direction))

        % plot passive
        raster = td_pas_avg(trialnum).(signal_name)';
        subplot(num_dirs,2,2*(trialnum-1)+2)
        imagesc(raster,clim);
        hold on
        plot([1 1]*num_bins_before,[0 size(raster,1)+1],'--w','linewidth',3)
        plot([1 1]*(num_bins_before+15),[0 size(raster,1)+1],'--w','linewidth',3)
        hold off
        set(gca,...
            'box','off',...
            'tickdir','out',...
            'xtick',binvec,...
            'xticklabel',timevec,...
            'ytick',[]);
        % xlabel('Time after bump onset (ms)')
        % ylabel('Neuron')
        ylabel(sprintf('Target Direction: %f',td_pas_avg(trialnum).target_direction))

        colormap(cm_viridis)
    end
