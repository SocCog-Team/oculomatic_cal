function out = ocu_read_bin_file(filepath,TOPLOT)
% parse and plot oculomatic file created by oculomatic version AU 20170705
if nargin < 2,
	TOPLOT = 0;
end

fileID = fopen(filepath);
A = fread(fileID,[4, Inf], 'double');
fclose(fileID);

out.x = A(1,:);
out.y = A(2,:);
out.a = A(3,:);
out.t = A(4,:);

if TOPLOT,
	timeaxis = A(4,:) - A(4,1);
	figure
	subplot(4,1,1)
	plot(timeaxis,[NaN diff(A(4,:))]);
	title('timestamps')
	
	subplot(4,1,2)
	plot(timeaxis,A(1,:),'.');
	title('x values')
	
	subplot(4,1,3)
	plot(timeaxis,A(2,:),'.');
	title('y values')
	
	subplot(4,1,4)
	plot(timeaxis,A(3,:),'.');
	title('area values')
end