function ocu_calibrate
% ocu_calibrate  - Calibrate Oculomatic eyetracker
%
% Basic idea:
% - Present fixation point - saccade target
% - ***Subject acquires central fixation -> saccade -> fixation
% - ***Oculomatic records file
% - Read newest oculomatic file (or any previous one)
% - Select time periods to use (optional), otherwise automatic detection of two fixation loci is attempted
% - Apply current calibration and show result
% - Calculate new calibration (using linear regression), show result 
% - Update new calibration if needed
% - Do it for several target stimulus positions
% - ... PROFIT!
%
% REQUIRES:	OCU_READ_BIN_FILE
%
% See also OCU_READ_BIN_FILE
%
%
% Author(s):	I.Kagan, DAG, DPZ
% URL:		http://www.dpz.eu/dag
%
% Change log:
% 20170706:	Created function (IK)
% ...
% $Revision: 1.0 $  $Date: 2017-07-06 22:45:34 $
%%%%%%%%%%%%%%%%%%%%%%%%%[DAG mfile header version 1]%%%%%%%%%%%%%%%%%%%%%%%%% 



% GUI
gui_bgcol = [0.75 0.75 0.75];
gui_butcol1 = [0.7569    0.8667    0.7765];
gui_butcol2 = [0.5020    0.5020    1.0000];
stim_display_zoom = 1;


h = findobj('Tag','Ocu calibrate');
if ~isempty(h);
	delete(h);
else
	% Defaults

	ocu_bin_path = pwd;
	
	StimPos	= [0 0; 10 0]; % deg, relative to monitor center [x1, y1; x2 y2]
	StimR	= 0.25; % deg

	
	% raw eye position (will be read from oculomatic file)
	eyepos_t = [];
	eyepos_x = [];
	eyepos_y = [];
	
	StimStartTime = 0;
	StimEndTime = 0;
	
	C.vd_cm			= 57.3; % cm
	C.screen_w_cm		= 59.8; % cm
	C.screen_h_cm		= 33.6; % cm
	
	C.StimDuration		= 3; % s
	C.cal			= [1 0 1 0]; % x gain x offset y gain y offset
	
	% End of defaults
	
end;

h0 = figure('Backingstore','off','Name','Ocu calibrate',...
        'Resize','On', 'Menubar','none',...
        'Color',gui_bgcol, ...
        'InvertHardcopy','off', ...
        'NumberTitle','off', ...
        'PaperPosition',[18 180 576 432], ...
        'PaperUnits','points', ...
        'Position',[100 100 800 800], ...
        'Tag','Ocu calibrate', ...
	'KeyPressFcn', @keyPress, ...
        'ToolBar','none');


hocu_bin_path = uicontrol('Parent',h0, ...
                'Units','points', ...
                'BackgroundColor',[1 1 1], ...
                'ListboxTop',0, ...
                'Units','normalized', ...
                'Position',[0.3 0.95 0.65 0.05], ...
                'String',ocu_bin_path, ...
                'Style','edit', ...
                'Tag','ocu_bin_path');
	

hPresent_stimuli = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol1, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.85 0.2 0.1], ...
        'String','Present stimuli', ...
	'Callback',@Present_stimuli_Callback,...
        'Tag','Present stimuli');

hstim_pos = uitable(h0,'Data',StimPos,'Units','normalized','Position',[0.3 0.85 0.23 0.07],...
	'ColumnName',{'x','y'},'ColumnEditable',true,'CellEditCallback',@stim_edit_Callback);

aspect_ratio = C.screen_w_cm/C.screen_h_cm;
hstim_display = axes('Units','normalized','Position',[0.2 0.4 0.4*aspect_ratio 0.4],...
		'XLimMode','manual','YLimMode','manual','Box','on','NextPlot','add');

hzoom = uicontrol('Parent',h0, ...
                'Units','points', ...
                'BackgroundColor',[0.8 0.8 0.9], ...
                'ListboxTop',0, ...
                'Units','normalized', ...
                'Position',[0.05 0.75 0.05 0.05], ...
                'String',num2str(stim_display_zoom), ...
                'Style','edit', ...
		'Callback',@stim_display_zoom_Callback,...
                'Tag','stim_display_zoom');

uicontrol('Style','text',...
        'Units','normalized', ...
	'Background',gui_bgcol,...
        'Position',[0.05 0.8 0.05 0.025], ...
        'String','zoom');

hreset_stim_time = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol1, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.6 0.1 0.05], ...
        'String','Reset stim time', ...
	'Callback',@rest_stim_time_Callback,...
        'Tag','Reset stim time');

heyepos = line(NaN,NaN,'Marker','.','Color',[0.5 0.5 0.5],'MarkerFaceColor',[0 0 0], 'MarkerEdgeColor',[0 0 0]);	
hstim_1 = line(StimPos(1,1),StimPos(1,2),'Marker','o','MarkerSize',10,'MarkerEdgeColor',[1 0 0],'MarkerFaceColor',[1 0 0]);
hstim_2 = line(StimPos(2,1),StimPos(2,2),'Marker','o','MarkerSize',10,'MarkerEdgeColor',[1 0 0],'MarkerFaceColor',[1 0 0]);


stim_edit_Callback;
update_stim_display;

heyepos_display = axes('Units','normalized','Position',[0.2 0.05 0.75 0.3],...
		'XLimMode','auto','YLimMode','auto','Box','on','NextPlot','replace',...
		'ButtonDownFcn',@select_eyepos_time_range_Callback);

heyepos_x = line(NaN,NaN,'Marker','.','Color',[0.5 0.5 0.5],'MarkerEdgeColor',[0    0.4980         0]);
heyepos_y = line(NaN,NaN,'Marker','.','Color',[0.5 0.5 0.5],'MarkerEdgeColor',[0.4784    0.0627    0.8941]);
hStimStartTime = line(NaN,NaN,'Marker','none','Color',[0 0 0]);
hStimEndTime = line(NaN,NaN,'Marker','none','Color',[0 0 0]);
heyepos_x1_sel = line(NaN,NaN,'Marker','none','Color',[0 1 0]);
heyepos_y1_sel = line(NaN,NaN,'Marker','none','Color',[1 0 1]);
heyepos_x2_sel = line(NaN,NaN,'Marker','none','Color',[0 1 0]);
heyepos_y2_sel = line(NaN,NaN,'Marker','none','Color',[1 0 1]);


hocu_file = uicontrol('Style','text',...
        'Units','normalized', ...
	'Background',gui_bgcol,...
        'Position',[0.2 0.35 0.7 0.025], ...
	'FontSize',10,...
        'String','no ocu bin file');

hread_ocu = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol2, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.35 0.1 0.05], ...
        'String','Read ocu...(r)', ...
	'Callback',@read_ocu_Callback,...
        'Tag','Read ocu...');

hread_ocu_newest = uicontrol('Parent',h0,...
	'Style','checkbox','Units','Normalized',...
	'Background',gui_bgcol,...
        'Position',[0.05 0.4 0.1 0.025],'String','newest','Value',1);

hnew_cal = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol2, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.3 0.1 0.05], ...
        'String','New cal...(n)', ...
	'Callback',@new_cal_Callback,...
        'Tag','New cal... ');


hload_cal = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol2, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.2 0.1 0.05], ...
        'String','Load cal...', ...
	'Callback',@load_cal_Callback,...
        'Tag','Load cal...');

hsave_cal = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol2, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.15 0.1 0.05], ...
        'String','Save cal...(s)', ...
	'Callback',@save_cal_Callback,...
        'Tag','Save cal...');

hsave_cal_as = uicontrol('Parent',h0, ...
        'Units','points', ...
        'BackgroundColor',gui_butcol2, ...
        'ListboxTop',0, ...
        'Units','normalized', ...
        'Position',[0.05 0.1 0.1 0.05], ...
        'String','Save cal as...', ...
	'Callback',@save_cal_as_Callback,...
        'Tag','Save cal as...');

hcal_file = uicontrol('Style','text',...
        'Units','normalized', ...
	'Background',gui_bgcol,...
        'Position',[0.6 0.875 0.35 0.05], ...
        'String','Default calibration');

hcal_param = uicontrol('Parent',h0, ...
	'Units','points', ...
	'BackgroundColor',[1 1 1], ...
	'ListboxTop',0, ...
	'Units','normalized', ...
	'Position',[0.6 0.85 0.1 0.05], ...
	'String',fieldnames(C), ...
	'Style','popupmenu', ...
	'Tag','param', ...
	'Callback',@select_cal_param_Callback,...
	'Value',1);

hcal_val = uicontrol('Parent',h0, ...
	'Units','points', ...
	'BackgroundColor',[1 1 1], ...
	'ListboxTop',0, ...
	'Units','normalized', ...
	'Position',[0.7 0.85 0.25 0.05], ...
	'String','', ...
	'Style','edit', ...
	'Callback',@select_cal_val_Callback,...
	'Tag','value');

param_names = get(hcal_param,'String');
set(hcal_val,'String',num2str(C.(param_names{1})));


	% Callback functions
	function load_cal_Callback(hObject,eventdata)
		[cal_filename,cal_pathname]=uigetfile('*.mat','Load calibration'); 
		temp = load([cal_pathname cal_filename]); 
		C = temp.C;
		set(hcal_file,'String',[cal_pathname cal_filename]);
		select_cal_param_Callback;
		update_stim_display;
	end


	function read_ocu_Callback(hObject,eventdata)
		
		if 0 % test version - artificial datastream
			
		n_stim_dur = C.StimDuration*200; % n samples at 200 Hz
		eyepos_x = [zeros(1,100) ones(1,n_stim_dur) 2*ones(1,n_stim_dur)] + randn(1,2*n_stim_dur+100)/5;
		eyepos_y = 2 + [zeros(1,100) ones(1,n_stim_dur) 2*ones(1,n_stim_dur)] + randn(1,2*n_stim_dur+100)/5;
		eyepos_t = [-0.495:0.005:2*C.StimDuration];
		
		StimEndTime = StimEndTime - StimStartTime;
		StimStartTime = StimStartTime - StimStartTime;
		
		% end of test version - artificial datastream
		
		else % real reading of ocu bin file
			
			ocu_bin_path = get(hocu_bin_path,'String');
			
			if get(hread_ocu_newest,'Value'), % get most recent file
				d = dir([ocu_bin_path filesep '*.bin']);
				[dx,dx] = sort([d.datenum]);
				ocu_bin_file = d(dx(end)).name; 
			else
				[ocu_bin_file,ocu_bin_path]=uigetfile('*.bin','Load ocu bin file',ocu_bin_path);
				if ~ocu_bin_file,
					return;
				else
					set(hocu_bin_path,'String',ocu_bin_path);
				end
				
			end
			ocu = ocu_read_bin_file([ocu_bin_path filesep ocu_bin_file]);
				
			eyepos_x = ocu.x;
			eyepos_y = ocu.y;
			eyepos_t = ocu.t;
			
			set(hocu_file,'String',[ocu_bin_path filesep ocu_bin_file]);
			
			if ~StimStartTime, % did not run stimulus presentation yet, just inspect the eye movements
				StimStartTime = eyepos_t(1);
				StimEndTime = eyepos_t(end);
			end
			
			% align time to start of ocu bin recording
			StimStartTime = StimStartTime - eyepos_t(1);
			StimEndTime = StimEndTime - eyepos_t(1);
			eyepos_t = eyepos_t - eyepos_t(1);
			
		end
		
		set(h0,'CurrentAxes',heyepos_display);
		delete(findobj(heyepos_display,'Tag','time selection box'));
		set(findobj(heyepos_display,'Tag','selected data'),'Visible','off');
				
		set(heyepos_x,'XData',eyepos_t,'Ydata',eyepos_x); 
		set(heyepos_y,'XData',eyepos_t,'Ydata',eyepos_y);
		
		y = get(heyepos_display,'Ylim');
		set(hStimStartTime,'XData',[StimStartTime StimStartTime],'Ydata',y);
		set(hStimEndTime,'XData',[StimEndTime StimEndTime],'Ydata',y);
		
			
		set(h0,'CurrentAxes',hstim_display);
		set(heyepos,'XData',eyepos_x*C.cal(1) + C.cal(2),'Ydata',eyepos_y*C.cal(3) + C.cal(4)); 
		
		set_figure_focus(hread_ocu);
		
	end

	function new_cal_Callback(hObject,eventdata)
		% this function takes into account StimPos and raw oculomatic file and calculated automatic linear 2-point calibration
		
		% raw eyepos signal
		eyepos_t = get(heyepos_x,'XData');
		eyepos_x = get(heyepos_x,'YData');
		eyepos_y = get(heyepos_y,'YData');
		
		htsb = findobj(heyepos_display,'Tag','time selection box');
		
		if ~isempty(htsb), % use manually selected time periods
			htsb = sort(htsb);
			tsb(1,:) = get(htsb(1),'Xdata'); 
			tsb(2,:) = get(htsb(2),'Xdata');
			period2take1 = find(eyepos_t > tsb(1,1) & eyepos_t < tsb(1,2));
			period2take2 = find(eyepos_t > tsb(2,1) & eyepos_t < tsb(2,2));		
			
		else
			period2take1 = find(eyepos_t > StimStartTime + C.StimDuration/2 & eyepos_t < StimStartTime + (C.StimDuration-0.1));
			period2take2 = find(eyepos_t > StimStartTime + (C.StimDuration + C.StimDuration/2) & eyepos_t < StimStartTime + 2*C.StimDuration-0.1);
			
		end
		
		t1 = eyepos_t(period2take1);
		t2 = eyepos_t(period2take2);
		
		mX1 = median(eyepos_x(period2take1));
		mX2 = median(eyepos_x(period2take2));
		
		mY1 = median(eyepos_y(period2take1));
		mY2 = median(eyepos_y(period2take2));
		
		set(h0,'CurrentAxes',heyepos_display);
		set(heyepos_x1_sel,'Xdata',[t1(1) t1(end)],'Ydata',[mX1 mX1],'Tag','selected data','Visible','on');
		set(heyepos_y1_sel,'Xdata',[t1(1) t1(end)],'Ydata',[mY1 mY1],'Tag','selected data','Visible','on');
		set(heyepos_x2_sel,'Xdata',[t2(1) t2(end)],'Ydata',[mX2 mX2],'Tag','selected data','Visible','on');
		set(heyepos_y2_sel,'Xdata',[t2(1) t2(end)],'Ydata',[mY2 mY2],'Tag','selected data','Visible','on');
		
		
		if (StimPos(1,1) - StimPos(2,1)) ~= 0, % calculate horizontal cal
			[r,xgain,xoffset] = ocu_regression([mX1 mX2],[StimPos(1,1) StimPos(2,1)]);
			C.cal([1 2]) = [xgain xoffset];
		end
		if (StimPos(1,2) - StimPos(2,2)) ~= 0, % calculate vertical cal
			[r,ygain,yoffset] = ocu_regression([mY1 mY2],[StimPos(1,2) StimPos(2,2)]);
			C.cal([3 4]) = [ygain yoffset];
		end
		select_cal_param_Callback;
	end

	function save_cal_Callback(hObject,eventdata) 
		cal_name = get(hcal_file,'String');
		save(cal_name,'C');
	end

	function save_cal_as_Callback(hObject,eventdata)
		[cal_filename,cal_pathname]=uiputfile('*.mat','Save calibration');
		save([cal_pathname cal_filename],'C');
	end


	function select_cal_param_Callback(hObject,eventdata)
		i = get(hcal_param,'Value'); 
		fnames = get(hcal_param,'String');
                fname = fnames{i}; 
		set(hcal_val,'String',num2str(C.(fname),3));
		% read_ocu_Callback;
		update_stim_display;
	end
        
	function select_cal_val_Callback(hObject,eventdata)
		val = str2num(get(hcal_val,'String'));
                i = get(hcal_param,'Value'); 
		fnames = get(hcal_param,'String'); 
		fname = fnames{i}; 
		C.(fname)=val;
		select_cal_param_Callback;
		
	end
		
	update_stim_display;function stim_edit_Callback(hObject,eventdata)
		StimPos = get(hstim_pos,'Data');
		set(h0,'CurrentAxes',hstim_display); hold on;
		set(hstim_1,'XData',StimPos(1,1),'Ydata',StimPos(1,2)); 
		set(hstim_2,'XData',StimPos(2,1),'Ydata',StimPos(2,2));
	end

	function update_stim_display
		aspect_ratio = C.screen_w_cm/C.screen_h_cm;
		set(hstim_display,'Units','normalized','Position',[0.2 0.4 0.4*aspect_ratio 0.4],...
		'XLim',[-cm2deg(C.vd_cm,C.screen_w_cm/2) cm2deg(C.vd_cm,C.screen_w_cm/2)]/stim_display_zoom,...
		'YLim',[-cm2deg(C.vd_cm,C.screen_h_cm/2) cm2deg(C.vd_cm,C.screen_h_cm/2)]/stim_display_zoom,...
		'XLimMode','manual','YLimMode','manual','Box','on','NextPlot','add');
	
		set(heyepos,'XData',eyepos_x*C.cal(1) + C.cal(2),'Ydata',eyepos_y*C.cal(3) + C.cal(4));
	end

	function stim_display_zoom_Callback(hObject,eventdata)
		stim_display_zoom = str2num(get(hObject,'String'));
		update_stim_display;
	end

	function select_eyepos_time_range_Callback(hObject,eventdata)
		
		point1 = get(hObject,'CurrentPoint');    % button down detected
		rbbox;			% return figure units
		point2 = get(hObject,'CurrentPoint');    % button up detected
		point1 = point1(1,1:2);              % extract x and y
		point2 = point2(1,1:2);
		p1 = min(point1,point2);             % calculate locations
		offset = abs(point1-point2);         % and dimensions
		x = [p1(1) p1(1)+offset(1) p1(1)+offset(1) p1(1) p1(1)];
		y = [p1(2) p1(2) p1(2)+offset(2) p1(2)+offset(2) p1(2)];
		hl = line(x,y,'LineWidth',3);          % draw box around selected region
		
		set(hl,'Tag','time selection box');
		
		
	end

	function Present_stimuli_Callback(hObject,eventdata)
			
		screens=Screen('Screens');
		screenNumber=max(screens);
	
		white=WhiteIndex(screenNumber);
		black=BlackIndex(screenNumber);
		% gray=round((white+black)/2);

		[w, windowRect] = PsychImaging('OpenWindow', screenNumber, black);
		[SCREEN.screen_w_pix, SCREEN.screen_h_pix] = Screen('WindowSize', w);
		SCREEN.screen_w_cm = C.screen_w_cm;
		SCREEN.screen_h_cm = C.screen_h_cm;
		
		[xCenter, yCenter] = RectCenter(windowRect);
		
		% Transform stimulus position in deg (relative to center) to pixels (from upper left corner)
		StimR_pix = deg2pix(C.vd_cm,StimR,SCREEN);

		[x1, y1] = deg2pix_xy(C.vd_cm, StimPos(1,1), StimPos(1,2), SCREEN);
		[x2, y2] = deg2pix_xy(C.vd_cm, StimPos(2,1), StimPos(2,2), SCREEN);
		
		% Use realtime priority for better timing precision:
		priorityLevel=MaxPriority(w);
		% Priority(priorityLevel);
		
		HideCursor; 

		Screen('FillOval', w,[255 255 255], [x1-StimR_pix y1-StimR_pix x1+StimR_pix y1+StimR_pix]);
		Screen('Flip', w);
		StimStartTime = GetSecs;
		WaitSecs(C.StimDuration);
		Screen('FillOval', w,[255 255 255], [x2-StimR_pix y2-StimR_pix x2+StimR_pix y2+StimR_pix]);
		Screen('Flip', w);
		WaitSecs(C.StimDuration);
		StimEndTime = GetSecs;
		
		
		% Priority(0);
		Screen('Close');
		sca;
		ShowCursor;
		
	end


	function rest_stim_time_Callback(hObject,eventdata)
		StimStartTime = 0;
		StimEndTime = 0;
	end

	function keyPress(hObject,eventdata)
		switch eventdata.Key
			case 'r'
				read_ocu_Callback;
			case 'n'
				new_cal_Callback;
			case 's'
				save_cal_Callback;
		end
	end

end % of main function

% here are not nested functions


function dist_deg = cm2deg(vd_cm,dist_cm)
dist_deg = 2*atan((dist_cm/2)/vd_cm)/(pi/180); 
end

function dist_cm = deg2cm(vd,dist_deg)
dist_cm = 2*vd*tan((0.5*dist_deg)*pi/180);
end

function  [dist_pixel] = deg2pix(vd_cm,distance_deg,SCREEN)

% degrees to cm
distance_cm = deg2cm(vd_cm, distance_deg);

% cm to pixels
pixels_per_cm = SCREEN.screen_w_pix / SCREEN.screen_w_cm;
dist_pixel  = round(distance_cm * pixels_per_cm);

end

function  [pixels_x, pixels_y] = deg2pix_xy (vd_cm, distance_deg_x, distance_deg_y, SCREEN)

center_x = SCREEN.screen_w_pix / 2;
center_y = SCREEN.screen_h_pix / 2;
%degrees to cm from the middle
distance_cm_x = deg2cm(vd_cm, distance_deg_x);
distance_cm_y = deg2cm(vd_cm, distance_deg_y); 
% cm to pixels
pixels_per_cm_x = SCREEN.screen_w_pix / SCREEN.screen_w_cm;
pixels_per_cm_y = SCREEN.screen_h_pix / SCREEN.screen_h_cm;

n_pixels_x  = distance_cm_x * pixels_per_cm_x;
n_pixels_y  = distance_cm_y * pixels_per_cm_y;

pixels_x = round(center_x + n_pixels_x);
pixels_y = round(center_y - n_pixels_y);

end


function set_figure_focus(hObject)
% see https://de.mathworks.com/matlabcentral/answers/33661-using-a-keypress-to-activate-a-button
set(hObject, 'Enable', 'off');
drawnow;
set(hObject, 'Enable', 'on');
end