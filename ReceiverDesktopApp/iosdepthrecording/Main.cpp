#include <iostream> // for standard I/O
#include <string>   // for strings
#include <iomanip>  // for controlling float print precision
#include <sstream>  // string to number conversion
#include <chrono>
#include <thread>
#include <stdlib.h>     //for using the function sleep
#include <windows.h>
#include <direct.h>
#include <stdio.h>
#include <fstream>
#include <opencv2/core/core.hpp>        // Basic OpenCV structures (cv::Mat, Scalar)
#include <opencv2/imgproc/imgproc.hpp>  // Gaussian Blur
#include <opencv2/videoio/videoio.hpp>
#include <opencv2/highgui/highgui.hpp>  // OpenCV window I/O

using namespace std;
using namespace cv;

// ###########################################################
// ################# Setup Instructions ######################
// ###########################################################
/*
- Download and extract OpenCV 3.2.0 Win pack from https://opencv.org/releases.html and extract it YOUR_FOLDER
- Open iosdepthrecording -> Properties and set the following values:
-- VC++ Directories -> IncludePath: YOUR_FOLDER\opencv\build\include;$(IncludePath)
-- Linker -> General -> AdditionalLibraryDirectories: YOUR_FOLDER\opencv\build\x64\vc14\lib;%(AdditionalLibraryDirectories)
-- Linker -> Eingabe -> AdditionalDependencies: opencv_world320.lib;%(AdditionalDependencies)
*/
// ###########################################################
// ##################### Settings ############################
// ###########################################################

// #### Location of the Source
const string dirOfSource = "C:/xampp/htdocs/videos/input/";

// #### Location of Background Video
const string backgroundVideo = "../../../properties/hintergrund180x320.mp4";

// #### Output Settings
const string outputImageDir = "C:/xampp/htdocs/videos/output/";
const string outputVideoDir = "C:/xampp/htdocs/videos/output/";
const int outputFps = 30; // Should be equal to delivered video
const int outputCodec = CV_FOURCC('M', 'J', 'P', 'G');

// #### How the video parts are named. Between the Pre and Post Part is the Counter of the video part inserted.
const string urlVideoPre = "video";
const string urlImagePre = "image";
const string urlColorPre = "Color";
const string urlDepthPre = "Depth";
const string urlPost = ".ts";
const string urlBinaryPost = ".binaryDepth";

// #### Depth is transmitted as the Disparity 1/Meter but scaled by a minDisparity and maxDisparity value set in the iOS App (in streamingConfiguration.plist).
// #### Those values need to be equal in both Apps.
const float minDisparity = 0.0;
const float maxDisparity = 5.0;

const double addToFPSToHandleDelay = 2;

// #### Delete old input files
const bool deleteOldInputFiles = true;

// #### Morph Parameters
const int morphRadius = 4; // 0 - disabled; > 1 - enabled
const int morphShape = MORPH_ELLIPSE; // or MORPH_RECT or MORPH_CROSS

// #### Play Video/Image in Loop
const bool loop = true;

// #### If video und image exists open the image if this value is true, the video if this value is false
const bool imageHasHigherPriority = true;

// ###########################################################
// ###########################################################
// ###########################################################






void playVideoPart(int i);
void showFrame(cv::Mat frame);

inline bool file_exists(const string& name);
string dirnameOf(const string& fname);

int DeleteDirectoryRecursive(const string &refcstrRootDirectory, bool bDeleteSubdirectories);

VideoCapture captureVideo;

ifstream fin;

VideoCapture hintergrundVideo;

VideoWriter outputWriter;

std::chrono::high_resolution_clock::time_point tVideoPartStart;

std::chrono::high_resolution_clock::time_point t1;

double fps = 1;

double videoLengthSeconds = 1;

int initialized = false;

int isImage = false;



int main(int argc, char *argv[])
{
	//depthBinaryRead();

	//system("pause");
	//return 0;

	const string urlPre = dirOfSource;

	// Delete old directories and files
	if (deleteOldInputFiles)
	{
		int iRC = DeleteDirectoryRecursive(urlPre, false);
		if (iRC) {
			std::cout << "Error " << iRC << std::endl;
			return -1;
		}
		do {
			Sleep(100);
		} while (file_exists(urlPre));
	}

	// Create necessary directories
	_mkdir(dirnameOf(backgroundVideo).c_str());
	_mkdir(dirnameOf(outputVideoDir).c_str());
	_mkdir(dirnameOf(urlPre).c_str());

	// Create necessary files
	std::ofstream putphpfile(dirnameOf(dirOfSource) + "/put.php");
	putphpfile << "<?php\n$putdata = fopen(\"php://input\", \"r\");\n$fp = fopen(\"tmp\".$_GET['filename'], \"w\");\nwhile ($data = fread($putdata, 1024)) fwrite($fp, $data);\n" <<
		"fclose($fp);\nrename(\"tmp\".$_GET['filename'], $_GET['filename']);\nfclose($putdata);\nif(strpos($_GET['filename'], '.zip') !== false) {\n	$zip = new ZipArchive;\n" <<
		"	$res = $zip->open($_GET['filename']);\n	if ($res === TRUE) {\n		$zip->extractTo(getcwd());\n		$zip->close();\n	}\n	unlink($_GET['filename']);\n}\n ?>";
	//\nrename(\"tmp\".$_GET['filename'], $_GET['filename']);
	putphpfile.close();

	hintergrundVideo = VideoCapture(backgroundVideo);

	bool waitMessageDisplayed = false;

	t1 = std::chrono::high_resolution_clock::now();

	int waitCounter = 0;

	for (int videoPartIndex = 0; true; videoPartIndex++)
	{
		// Lets the Programm wait for files from the iOS App
		if (!(file_exists(urlPre + urlVideoPre + urlColorPre + to_string(videoPartIndex) + urlPost) && file_exists(urlPre + urlVideoPre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost)) &&
			!(file_exists(urlPre + urlImagePre + urlColorPre + to_string(videoPartIndex) + urlPost) && file_exists(urlPre + urlImagePre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost))) {
			if (!waitMessageDisplayed) {
				//cout << "Waiting for receiving data from the iOS App..." << endl;
				cout << "Waiting for videoPartIndex " << videoPartIndex << endl;
				waitMessageDisplayed = true;
			}
			Sleep(50);
			if (videoPartIndex > 0) {
				waitCounter++;
				if (waitCounter > 5000 / 50) {
					if (initialized)
					{
						outputWriter.release();
						cout << "Writing Output Video finished" << endl;
						initialized = false;
					}
					waitCounter = 0;
					videoPartIndex = 0;
					waitMessageDisplayed = false;
					hintergrundVideo = VideoCapture(backgroundVideo);
				}
			}
			videoPartIndex--;

			tVideoPartStart = std::chrono::high_resolution_clock::now();

			continue;
		}
		waitMessageDisplayed = false;
		waitCounter = 0;

		isImage = false;
		string urlMediaTypePre = urlVideoPre;
		if ((imageHasHigherPriority && file_exists(urlPre + urlImagePre + urlColorPre + to_string(videoPartIndex) + urlPost)))
		{
			urlMediaTypePre = urlImagePre;
			isImage = true;
		}


		std::chrono::high_resolution_clock::time_point tOpenStart = std::chrono::high_resolution_clock::now();

		if (file_exists(urlPre + urlMediaTypePre + urlColorPre + to_string(videoPartIndex) + urlPost)) {
			captureVideo = VideoCapture(urlPre + urlMediaTypePre + urlColorPre + to_string(videoPartIndex) + urlPost);
		}

		if (file_exists(urlPre + urlMediaTypePre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost)) {
			fin = ifstream(urlPre + urlMediaTypePre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost, ios::binary);

			UINT8 sMetaData;
			fin.read(reinterpret_cast<char*>(&sMetaData), sizeof(UINT8));
			uint frames = (uint)sMetaData;

			fps = (double) frames + addToFPSToHandleDelay;

			fin.read(reinterpret_cast<char*>(&sMetaData), sizeof(UINT8));
			uint videoLengthMillisecondsMSB = (uint)sMetaData;
			fin.read(reinterpret_cast<char*>(&sMetaData), sizeof(UINT8));
			uint videoLengthMillisecondsLSB = (uint)sMetaData;
			uint videoLengthMilliseconds = videoLengthMillisecondsMSB * 256 + videoLengthMillisecondsLSB;

			videoLengthSeconds = ((double)videoLengthMilliseconds) / 1000.0;

			//cout << "videoLengthSeconds: " << videoLengthSeconds << endl;
		}

		if (!captureVideo.isOpened())
		{
			videoPartIndex--;
			continue;
		}

		std::chrono::high_resolution_clock::time_point tOpenEnd = std::chrono::high_resolution_clock::now();
		std::chrono::duration<double, std::milli> time_span_open = tOpenEnd - tOpenStart;
		int duration_open = (int)time_span_open.count();

		cout << "Loop for videoPartIndex " << videoPartIndex << " with " << fps << " frames, time to open: " << duration_open << "ms" << endl;


		/*
		fps = captureVideo.get(CV_CAP_PROP_FPS);
		//cout << "fps:" << fps << endl;
		if (fps > 100) {
			// Sometimes a wrong fps value of 180000 is delivered by the apple api
			fps = 40;
		}
		*/

		playVideoPart(videoPartIndex);

		captureVideo.release();
		fin.close();

		if (file_exists(urlPre + urlMediaTypePre + urlColorPre + to_string(videoPartIndex) + urlPost)) {
			remove((urlPre + urlMediaTypePre + urlColorPre + to_string(videoPartIndex) + urlPost).c_str());
		}
		if (file_exists(urlPre + urlMediaTypePre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost)) {
			remove((urlPre + urlMediaTypePre + urlDepthPre + to_string(videoPartIndex) + urlBinaryPost).c_str());
		}

		if (isImage) {
			videoPartIndex = -1;
		}
		
	}

}

void playVideoPart(int i)
{

	int countFramesPlayed = 0;

	cv::Mat videoFrame;
	cv::Mat backgroundFrame;




	float channel[3];

	float schannel[15];
	float s[15];
	float powerNonInterleaved[3];
	for (int b = 1; b <= 3 * 5; b++) {
		schannel[b - 1] = pow(2, -((b - 1) / 3) - 1);
		s[b - 1] = pow(2, -b);
	}
	for (int b = 1; b <= 3; b++) {
		powerNonInterleaved[b - 1] = pow(2, -b*5);
	}

	if (!hintergrundVideo.read(backgroundFrame)) {
		hintergrundVideo = VideoCapture(backgroundVideo);
		hintergrundVideo.read(backgroundFrame);
	}

	while (captureVideo.read(videoFrame))
	{

		uint8_t* videoPtr = (uint8_t*)videoFrame.data;
		uint8_t* hintergrundPtr = (uint8_t*)backgroundFrame.data;

		int vWidth = videoFrame.cols;
		int vHeight = videoFrame.rows;
		int numberOfChannels = videoFrame.channels();

		Mat depthFrame = Mat::zeros(vHeight, vWidth, videoFrame.type());
		uint8_t* depthPtr = (uint8_t*)depthFrame.data;

		long sumDepth = 0;



		if (videoFrame.cols != backgroundFrame.cols || videoFrame.rows != backgroundFrame.rows) {
			resize(backgroundFrame, backgroundFrame, videoFrame.size(), 0, 0, INTER_CUBIC);
			//cout << "Resize" << endl;
		}



		int width = 240;
		int height = 320;

		Mat depthImage = Mat::zeros(height, width, CV_8U);
		uint8_t* depthImagePtr = (uint8_t*)depthImage.data;

		
		uint counter = 0;
		UINT8 s;
		while (counter < width * height && fin.read(reinterpret_cast<char*>(&s), sizeof(UINT8)))
		{
			depthImagePtr[counter] = (uint)s;
			counter++;
		}
		

		Mat depthImageScaled;

		resize(depthImage, depthImageScaled, cvSize(vWidth, vHeight));

		uint8_t* depthImageScaledPtr = (uint8_t*)depthImageScaled.data;

		for (int i = 0; i < vHeight; i++)
		{
			for (int j = 0; j < vWidth; j++)
			{
				int v = depthImageScaledPtr[i * vWidth + j];
				depthPtr[i * vWidth*numberOfChannels + j * numberOfChannels + 0] = v;
				depthPtr[i * vWidth*numberOfChannels + j * numberOfChannels + 1] = v;
				depthPtr[i * vWidth*numberOfChannels + j * numberOfChannels + 2] = v;
				sumDepth += v;
			}
		}



		// Write back decoded 
		depthFrame.data = depthPtr;

		
		// Binary Map Generation
		Mat binaryMap = Mat::zeros(depthFrame.size(), depthFrame.type());
		uint8_t* binaryMapPtr = (uint8_t*)binaryMap.data;
		float threshold = sumDepth / (vHeight * vWidth);
		for (int i = 0; i < vHeight; i++)
		{
			for (int j = 0; j < vWidth; j++)
			{
				int binaryValue = 1;
				if (depthImageScaledPtr[i * vWidth + j] < threshold)
				{
					binaryValue = 0;
				}
				for (int channel = 0; channel < numberOfChannels; channel++)
				{
					int pos = i * vWidth * numberOfChannels + j * numberOfChannels + channel;
					binaryMapPtr[pos] = binaryValue;
				}
			}
		}
		videoFrame.data = videoPtr;
		binaryMap.data = binaryMapPtr;

		
		if (morphRadius > 0)
		{
			Mat element = getStructuringElement(morphShape, Size(2 * morphRadius + 1, 2 * morphRadius + 1), Point(morphRadius, morphRadius));

			const int MORPH_OPEN = 2;
			const int MORPH_CLOSE = 3;
			morphologyEx(binaryMap, binaryMap, MORPH_OPEN, element, Point(-1, -1), 1);
			morphologyEx(binaryMap, binaryMap, MORPH_CLOSE, element, Point(-1, -1), 1);
		}
		
		
		Mat binaryMapInverted = Scalar::all(1) - binaryMap;



		countFramesPlayed++;
		
		std::chrono::high_resolution_clock::time_point t2 = std::chrono::high_resolution_clock::now();
		std::chrono::duration<double, std::milli> time_span = t2 - t1;
		int duration = (int)time_span.count();
		std::cout << "Video " << i << " Frame " << (countFramesPlayed < 10 ? " " : "") << countFramesPlayed << " - Duration: " << duration << " ms";

		t1 = std::chrono::high_resolution_clock::now();



		std::chrono::high_resolution_clock::time_point tNow = std::chrono::high_resolution_clock::now();
		std::chrono::duration<double, std::milli> timespanSinceFirstFrame = tNow - tVideoPartStart;
		int durationSinceFirstFrame = (int)timespanSinceFirstFrame.count();

		int durationShouldHavePassed = (int)(((double)countFramesPlayed) * videoLengthSeconds * 1000.0 / fps);
		
		if (durationSinceFirstFrame < durationShouldHavePassed) {
			cout << "   Wait: " << durationShouldHavePassed - durationSinceFirstFrame << " ms";
			cv::waitKey(durationShouldHavePassed - durationSinceFirstFrame);
		}
		cout << endl;




		Mat outputFrame;
		cv::hconcat(videoFrame, depthFrame, outputFrame);
		cv::hconcat(outputFrame, backgroundFrame, outputFrame);
		cv::hconcat(outputFrame, binaryMap.mul(255), outputFrame);
		cv::hconcat(outputFrame, videoFrame.mul(binaryMap) + backgroundFrame.mul(binaryMapInverted), outputFrame);

		showFrame(outputFrame);

		// Has to be repeated once for image or big video frames
 		if(isImage || duration > 100) {
			cv::waitKey(5);
			showFrame(outputFrame);
		}

		if (isImage)
		{
			__int64 now = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
			imwrite(outputImageDir + "image_" + to_string(now) + ".bmp", outputFrame);
		}
		else
		{
			if (!initialized)
			{
				Size outputSize = Size(outputFrame.cols, outputFrame.rows);
				__int64 now = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
				outputWriter = VideoWriter(outputVideoDir + "video_" + to_string(now) + ".mp4", outputCodec, outputFps, outputSize, true);
				initialized = true;
			}
			outputWriter.write(outputFrame);
		}
		

	}
	tVideoPartStart = std::chrono::high_resolution_clock::now();
}

void showFrame(cv::Mat frame) {
	cv::imshow("Stream", frame);

}


inline bool file_exists(const string& name) {
	struct stat buffer;
	return (stat(name.c_str(), &buffer) == 0);
}

string dirnameOf(const string& fname)
{
	size_t pos = fname.find_last_of("\\/");
	return (std::string::npos == pos) ? "" : fname.substr(0, pos);
}

int DeleteDirectoryRecursive(const string &refcstrRootDirectory, bool bDeleteSubdirectories)
{
	bool            bSubdirectory = false;       // Flag, indicating whether
												 // subdirectories have been found
	HANDLE          hFile;                       // Handle to directory
	std::string     strFilePath;                 // Filepath
	std::string     strPattern;                  // Pattern
	WIN32_FIND_DATA FileInformation;             // File information


	strPattern = refcstrRootDirectory + "\\*.*";
	hFile = ::FindFirstFile(strPattern.c_str(), &FileInformation);
	if (hFile != INVALID_HANDLE_VALUE)
	{
		do
		{
			if (FileInformation.cFileName[0] != '.')
			{
				strFilePath.erase();
				strFilePath = refcstrRootDirectory + "\\" + FileInformation.cFileName;

				if (FileInformation.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
				{
					if (bDeleteSubdirectories)
					{
						// Delete subdirectory
						int iRC = DeleteDirectoryRecursive(strFilePath, bDeleteSubdirectories);
						if (iRC)
							return iRC;
					}
					else
						bSubdirectory = true;
				}
				else
				{
					// Set file attributes
					if (::SetFileAttributes(strFilePath.c_str(),
						FILE_ATTRIBUTE_NORMAL) == FALSE)
						return ::GetLastError();

					// Delete file
					if (::DeleteFile(strFilePath.c_str()) == FALSE)
						return ::GetLastError();
				}
			}
		} while (::FindNextFile(hFile, &FileInformation) == TRUE);

		// Close handle
		::FindClose(hFile);

		DWORD dwError = ::GetLastError();
		if (dwError != ERROR_NO_MORE_FILES)
			return dwError;
		else
		{
			if (!bSubdirectory)
			{
				// Set directory attributes
				if (::SetFileAttributes(refcstrRootDirectory.c_str(),
					FILE_ATTRIBUTE_NORMAL) == FALSE)
					return ::GetLastError();

				// Delete directory
				if (::RemoveDirectory(refcstrRootDirectory.c_str()) == FALSE)
					return ::GetLastError();
			}
		}
	}

	return 0;
}

