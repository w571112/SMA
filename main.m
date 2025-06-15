clc;
clear all;close all;
warning('off','all');

%% 所有全局变量
global width;           global height;          %图像宽度高度
global cell_width;      global cell_height;      %图像宽度和高度方向上容纳的块个数
global windowSize;      global SADsize;         %块边长和计算SAD时的边长
global ref_pixel;       global ref_block;       %像素点和块的位置补偿
global searchwindow;    global not_found;       %搜索窗大小，无法匹配块的mv=【not_found not_found】
global average_level;                           
global threshold;                               
global upleft;          global downright;       
global imgpadG;         global imgprepadG;      %当前图像和前一帧图像的灰度图
global  const1;         global  const2;         

%% 创建新的视频序列，用于存放去噪后的图像
outputVideo = VideoWriter('_near_result.avi'); 
outputVideo.Quality = 100; 
outputVideo.FrameRate = 5; 
open(outputVideo); 
%% 读取视频 
mov=VideoReader("E:\downloade\SMA-Chip-level-Real-world-Low-Light-Video-Denoising-Based-on-Scalable-Motion-Analysis-main\dataset\noisy_near.avi");
n=mov.NumberOfFrames;
%% 创建新的文件夹，用于存放单帧的图像处理结果
%dirname='near_result_2222';
%directory=[cd,['\' dirname '\']];
%mkdir([cd,['\' dirname]]);
%ori_pic='ori_far.jpg';         %原始图片名称
%denos_pic='result_far.jpg';    %去噪后图片名称
directory = 'E:\downloade\SMA-Chip-level-Real-world-Low-Light-Video-Denoising-Based-on-Scalable-Motion-Analysis-main\speedtest';
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% 设置图片保存路径
ori_pic = fullfile(directory, 'ori_near.jpg');         % 图片保存路径  
denos_pic = fullfile(directory, 'result_near.jpg');    % 去噪后图片保存路径 

%% 变量初始化
average_level=5;  
searchwindow=48;  
windowSize=8;  scale=4; 

%total_unmatched = 0; % 初始化总未匹配块数%%%%%%%%%%%%%

ref_pixel=ceil(searchwindow/windowSize+1)*windowSize;
not_found=searchwindow+1;

filter=[1 4 7 4 1;4 16 26 16 4;7 26 41 26 7;4 16 26 16 4;1 4 7 4 1]; %原始5x5
filter=filter/sum(sum(filter));    

%% 处理部分
for outer_loop=2:n 

    fprintf('当前的外层循环变量值为  %d  \n',outer_loop);
    windowSize=8;  
    SADsize=windowSize*2; 
    upleft=(SADsize-windowSize)/2; 
    downright=windowSize+upleft-1; 
    ref_block=ref_pixel/windowSize; 

    
    if outer_loop==2 
        imgpre=read(mov,outer_loop-1); 
        [height,width,~]=size(imgpre); % 获取图像原始尺寸

%        cutw=2;cuth=1;
%        width=width/cutw;    
%        height=height/cuth;

        % 计算分块数量
        cell_height=floor(height/windowSize); 
        cell_width=floor(width/windowSize);
        height=windowSize*cell_height;
        width=windowSize*cell_width;
        imgpre=imgpre(1:height,1:width,:);% 裁剪图像

        % 图像填充
        imgprepad=padarray(imgpre,[ref_pixel,ref_pixel],'symmetric','both');% 对称填充
        clear imgpre;
        imgprepadG=double(rgb2gray(imgprepad));% 转换为灰度图并双精度化

        store=uint8(zeros(cell_height*scale,cell_width*scale)); 
        output=cell(cell_height*scale,cell_width*scale);        %用于存放输出的去噪图片
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %disp(['cell_height: ', num2str(cell_height)]);
        %disp(['cell_width: ', num2str(cell_width)]);
        %disp(['ref_pixel: ', num2str(ref_pixel)]);
        %disp(['windowSize: ', num2str(windowSize)]);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        mv=zeros(cell_height+ref_pixel/windowSize*2,cell_width+ref_pixel/windowSize*2,2);%初始运动矢量

    else% 
        cell_height=height/windowSize;
        cell_width=width/windowSize; 
        imgpre=outputD;
        imgprepad=padarray(imgpre,[ref_pixel,ref_pixel],'symmetric','both');  % 填充处理
        %%%%%%%%%%%%%%%%!!!!clear imgpre;
        imgprepadG=imgpadG;    % 传递灰度图像

    end

    %读取当前帧图像
    img=read(mov,outer_loop);
    img=img(1:height,1:width,:); 
    imgpad=padarray(img,[ref_pixel,ref_pixel],'symmetric','both');
    %%%%%%%%%%%%clear img;
    imgpadG=double(rgb2gray(imgpad));
    %写下当前图像     
    %name0=[directory num2str(outer_loop)  ori_pic];
    name0 = fullfile(directory, [num2str(outer_loop) '_ori_near.jpg']);% 生成文件名
    %% 计算自适应阈值
    thresh = getT(imgpadG,imgprepadG,SADsize)*1.5
    %thresh=25.7;
    threshold=thresh*SADsize*SADsize;

    %第一部分 运动估计 
    tic% 开始计时
    mv=mv_initialize(mv);% 

    %第二部分 运动矢量细化 
    cell_height=cell_height*2;
    cell_width=cell_width*2; 
    windowSize=windowSize/2;
    SADsize=windowSize*2;
    upleft=(SADsize-windowSize)/2;
    downright=windowSize+upleft-1; 
    ref_block=ref_pixel/windowSize; 
    threshold=thresh*SADsize*SADsize;
    mv_2=mv_refine(mv);% 运动矢量细化

   %匹配失败的地方进行全搜索
     for k0=0:cell_height*cell_width-1
           i0=floor(k0/cell_width)+1;
           j0=mod(k0,cell_width)+1; 
           i=i0+ref_block;% 计算全局位置
           j=j0+ref_block;
           flag1=(mv_2(i,j,1)==not_found);% 检查是否未找到匹配
           if flag1
               threshold=thresh*SADsize*SADsize;% 重置阈值
               curx=uint16((i-1)*windowSize+1);
               cury=uint16((j-1)*windowSize+1);
               mv_2(i,j,:)=search_T(curx,cury);  
           end
     end    

    %第三部分 运动矢量再细化  MSF
    cell_height=cell_height*2;
    cell_width=cell_width*2;
    windowSize=windowSize/2;
    SADsize=windowSize*2;
    upleft=(SADsize-windowSize)/2;  
    downright=windowSize+upleft-1;
    ref_block=ref_pixel/windowSize; 
    threshold=thresh*SADsize*SADsize;% 更新阈值
    mv_3=mv_refine(mv_2);

    %第四部分， TF
    count_match=zeros(cell_height,cell_width);% 初始化匹配计数器
    flag2=(mv_3(ref_block+1:ref_block+cell_height,ref_block+1:ref_block+cell_width,1)~=not_found);
    store=bitset(store,mod((outer_loop-1),average_level)+1,flag2); 
    % 计算累计匹配次数
    for i=1:average_level
         tmp=double(bitget(store,i));% 提取第i位的匹配状态
         count_match=count_match+tmp;% 累加
    end 

    count_match=imfilter(count_match,filter,'corr','symmetric','same');
    count_match(count_match<1)=1;

    threshold=thresh*SADsize*SADsize;% 最终阈值
   %!!!!输出结果 
  for k0=0:cell_height*cell_width-1 
        i0=floor(k0/cell_width)+1;j0=mod(k0,cell_width)+1;
        i=i0+ref_block;j=j0+ref_block;
        curx=(i-1)*windowSize+1;cury=(j-1)*windowSize+1;
         flag3=(mv_3(i,j,1)~=not_found);
         if flag3
         
            cur_block=imgpad(curx:curx+windowSize-1,cury:cury+windowSize-1,:);          
            mv_block=imgprepad(curx+mv_3(i,j,1):curx+mv_3(i,j,1)+windowSize-1,cury+mv_3(i,j,2):cury+mv_3(i,j,2)+windowSize-1,:);  

            % 时域加权平均
            output{i0,j0}=double(cur_block)./count_match(i0,j0)+double(mv_block).*(count_match(i0,j0)-1)./count_match(i0,j0);

         else% 匹配失败
                    sum_inframe=zeros(windowSize,windowSize,3);% 初始化空矩阵
                    [mv_out2,ct]=search_inframe(curx,cury,thresh*windowSize*windowSize); 
                    mv_out=(mv_out2-1);
                    for k=1:ct
                        sum_inframe=sum_inframe+double(imgpad(mv_out(1,k):mv_out(1,k)+windowSize-1,mv_out(2,k):mv_out(2,k)+windowSize-1,:));
                    end
           output{i0,j0}=sum_inframe./ct; 
         end
  end
    %%%%%%%%%%%%!!!!clear mv_3;clear mv_2;
    outputD=uint8(cell2mat(output));
    name = fullfile(directory, [num2str(outer_loop) '_result_far.jpg']);
    %name=[directory num2str(outer_loop) denos_pic];
    %imwrite(outputD,name);% 保存去噪后图像
    if outer_loop~=2
       % aviobj=addframe(aviobj,outputD);
       %writeVideo(outputVideo, outputD);  %不生成视频
    end
toc 
end
warning('on','all');
%aviobj=close(aviobj);
close(outputVideo); 

