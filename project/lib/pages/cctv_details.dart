import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'cctv_page.dart';

class CCTVDetails extends StatefulWidget {
  final String cameraUrl;
  final String cameraName;
  final String cameraId;
  final CCTVWebViewController webViewController;

  const CCTVDetails({
    required this.cameraUrl,
    required this.cameraName,
    required this.cameraId,
    required this.webViewController,
    Key? key,
  }) : super(key: key);

  @override
  _CCTVDetailsState createState() => _CCTVDetailsState();
}

class _CCTVDetailsState extends State<CCTVDetails> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> photoList = [];
  List<Map<String, dynamic>> videoList = [];
  bool isPhotosLoading = true;
  bool isVideosLoading = true;
  static const int pageSize = 10;
  bool hasMorePhotos = true;
  bool hasMoreVideos = true;
  String? nextPhotoPageToken;
  String? nextVideoPageToken;
  bool isPhotosLoadingMore = false;
  bool isVideosLoadingMore = false;
  final Map<String, String> _urlCache = {};
  bool _showStream = true;
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _liveStreamAvailable = false;
  Timer? _liveStreamTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
      checkLiveStreamAvailability();
    });
    checkLiveStreamAvailability();
    _liveStreamTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      checkLiveStreamAvailability();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectivitySubscription.cancel();
    _liveStreamTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    fetchFilesFromFolder("pictures${widget.cameraId}/", isPhoto: true).then((_) {
      setState(() {
        isPhotosLoading = false;
      });
    });
    fetchFilesFromFolder("videos${widget.cameraId}/", isPhoto: false).then((_) {
      setState(() {
        isVideosLoading = false;
      });
    });
  }

  Future<void> checkLiveStreamAvailability() async {
    try {
      final response = await http.get(Uri.parse(widget.cameraUrl))
          .timeout(Duration(seconds: 3));
      setState(() {
        _liveStreamAvailable = (response.statusCode == 200);
      });
    } catch (e) {
      setState(() {
        _liveStreamAvailable = false;
      });
    }
  }

  Future<String> _getCachedUrl(Reference ref) async {
    final String path = ref.fullPath;
    if (_urlCache.containsKey(path)) {
      return _urlCache[path]!;
    }
    final url = await ref.getDownloadURL();
    _urlCache[path] = url;
    return url;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<Map<String, dynamic>> processVideoFile(Reference item) async {
    String fileName = item.name;
    FullMetadata metadata = await item.getMetadata();
    DateTime modifiedTime = metadata.updated ?? DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(modifiedTime);
    String size = _formatFileSize(metadata.size ?? 0);

    return {
      "name": fileName,
      "date": formattedDate,
      "rawDate": modifiedTime.millisecondsSinceEpoch,
      "path": item.fullPath,
      "size": size,
      "url": null,
      "contentType": metadata.contentType ?? "video/mp4",
    };
  }

  Future<Map<String, dynamic>> processPhotoFile(Reference item) async {
    String fileName = item.name;
    String fileUrl = await _getCachedUrl(item);
    FullMetadata metadata = await item.getMetadata();
    DateTime modifiedTime = metadata.updated ?? DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(modifiedTime);
    String size = _formatFileSize(metadata.size ?? 0);

    return {
      "url": fileUrl,
      "name": fileName,
      "date": formattedDate,
      "rawDate": modifiedTime.millisecondsSinceEpoch,
      "path": item.fullPath,
      "size": size,
    };
  }

  Future<void> fetchFilesFromFolder(String folderPath, {required bool isPhoto}) async {
    if ((isPhoto && !hasMorePhotos) || (!isPhoto && !hasMoreVideos)) return;
    if ((isPhoto && isPhotosLoadingMore) || (!isPhoto && isVideosLoadingMore)) return;

    setState(() {
      if (isPhoto) {
        isPhotosLoadingMore = true;
      } else {
        isVideosLoadingMore = true;
      }
    });

    try {
      final options = ListOptions(
        maxResults: pageSize,
        pageToken: isPhoto ? nextPhotoPageToken : nextVideoPageToken,
      );

      final ListResult result = await FirebaseStorage.instance.ref(folderPath).list(options);
      final List<Map<String, dynamic>> newFiles = await Future.wait(
        result.items.map((item) => isPhoto ? processPhotoFile(item) : processVideoFile(item)),
      );

      newFiles.sort((a, b) {
        DateTime dateA = DateFormat('yyyy-MM-dd HH:mm').parse(a["date"]);
        DateTime dateB = DateFormat('yyyy-MM-dd HH:mm').parse(b["date"]);
        return dateB.compareTo(dateA);
      });

      setState(() {
        if (isPhoto) {
          if (nextPhotoPageToken == null) {
            photoList = newFiles;
          } else {
            photoList.addAll(newFiles);
            photoList.sort((a, b) {
              DateTime dateA = DateFormat('yyyy-MM-dd HH:mm').parse(a["date"]);
              DateTime dateB = DateFormat('yyyy-MM-dd HH:mm').parse(b["date"]);
              return dateB.compareTo(dateA);
            });
          }
          nextPhotoPageToken = result.nextPageToken;
          hasMorePhotos = result.nextPageToken != null;
          isPhotosLoadingMore = false;
        } else {
          if (nextVideoPageToken == null) {
            videoList = newFiles;
          } else {
            videoList.addAll(newFiles);
            videoList.sort((a, b) {
              DateTime dateA = DateFormat('yyyy-MM-dd HH:mm').parse(a["date"]);
              DateTime dateB = DateFormat('yyyy-MM-dd HH:mm').parse(b["date"]);
              return dateB.compareTo(dateA);
            });
          }
          nextVideoPageToken = result.nextPageToken;
          hasMoreVideos = result.nextPageToken != null;
          isVideosLoadingMore = false;
        }
      });
    } catch (e) {
      print("Error fetching files: $e");
      setState(() {
        if (isPhoto) {
          isPhotosLoadingMore = false;
        } else {
          isVideosLoadingMore = false;
        }
      });
    }
  }

  Future<void> _refreshMedia(bool isPhoto) async {
    if (isPhoto) {
      nextPhotoPageToken = null;
      hasMorePhotos = true;
      photoList.clear();
      setState(() => isPhotosLoading = true);
      await fetchFilesFromFolder("pictures${widget.cameraId}/", isPhoto: true);
      setState(() => isPhotosLoading = false);
    } else {
      nextVideoPageToken = null;
      hasMoreVideos = true;
      videoList.clear();
      setState(() => isVideosLoading = true);
      await fetchFilesFromFolder("videos${widget.cameraId}/", isPhoto: false);
      setState(() => isVideosLoading = false);
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final ref = FirebaseStorage.instance.ref(filePath);
      await ref.delete();
      _urlCache.remove(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        nextPhotoPageToken = null;
        nextVideoPageToken = null;
        hasMorePhotos = true;
        hasMoreVideos = true;
        photoList.clear();
        videoList.clear();
        isPhotosLoading = true;
        isVideosLoading = true;
      });
      _initializeData();
    } catch (e) {
      print("Error deleting file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showDeleteConfirmation(String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete File"),
          content: Text("Are you sure you want to delete this file?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.pop(context);
                deleteFile(filePath);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> openFile(String? url, String fileName, String filePath) async {
    if (url == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blue[700]),
                SizedBox(height: 16),
                Text(
                  "Loading video...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        final ref = FirebaseStorage.instance.ref(filePath);
        url = await _getCachedUrl(ref);
        Navigator.pop(context);
      } catch (e) {
        Navigator.pop(context);
        showErrorDialog(context, "Error loading video");
        return;
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      String localFilePath = "${dir.path}/$fileName";

      if (!File(localFilePath).existsSync()) {
        showDownloadProgress(context);
        await Dio().download(url, localFilePath);
        Navigator.pop(context);
      }

      OpenFilex.open(localFilePath);
    } catch (e) {
      print("Error opening file: $e");
      showErrorDialog(context, "Error opening file");
    }
  }

  void showDownloadProgress(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blue[700]),
                SizedBox(height: 16),
                Text(
                  "Downloading file...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaCard(Map<String, dynamic> item, bool isPhoto) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => openFile(item['url'], item['name'], item['path']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isPhoto
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item['url'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                )
                    : Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.videocam, color: Colors.blue[700], size: 30),
                    if (item['size'] != null)
                      Positioned(
                        bottom: 0,
                        child: Text(
                          item['size'],
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      item['date'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPhoto || item['url'] != null
                          ? Icons.download
                          : Icons.play_circle,
                      color: Colors.blue[700],
                    ),
                    onPressed: () => openFile(item['url'], item['name'], item['path']),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => showDeleteConfirmation(item['path']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, bool isPhoto) {
    return RefreshIndicator(
      onRefresh: () => _refreshMedia(isPhoto),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            fetchFilesFromFolder(
              isPhoto ? "pictures${widget.cameraId}/" : "videos${widget.cameraId}/",
              isPhoto: isPhoto,
            );
          }
          return true;
        },
        child: ListView.builder(
          physics: BouncingScrollPhysics(),
          itemCount: items.length + ((isPhoto ? hasMorePhotos : hasMoreVideos) ? 1 : 0),
          padding: EdgeInsets.only(bottom: 16),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Colors.blue[700]),
                ),
              );
            }
            return _buildMediaCard(items[index], isPhoto);
          },
        ),
      ),
    );
  }

  Widget _buildStreamContent() {
    if (!_showStream || widget.cameraUrl.isEmpty) {
      return Container();
    }

    if (!_isOnline || !_liveStreamAvailable) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text(
                'Offline',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              SizedBox(height: 4),
              Text(
                'Unable to connect to live stream',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        widget.webViewController.isInitialized
            ? Container(
          color: Colors.black,
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.cameraUrl),
            ),
            onWebViewCreated: (controller) {
              widget.webViewController.controller = controller;
            },
            initialSettings: InAppWebViewSettings(
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              supportZoom: false,
              useHybridComposition: true,
            ),
          ),
        )
            : Center(child: CircularProgressIndicator()),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _showStream = false;
        });
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            widget.cameraName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue[700],
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[700]!, Colors.grey[100]!],
              stops: [0.0, 0.3],
            ),
          ),
          child: Column(
            children: [
              // Live Stream Container
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildStreamContent(),
                ),
              ),

              // Detection History Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Detection History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue[50],
                  ),
                  tabs: [
                    Tab(
                      icon: Icon(Icons.photo_library),
                      text: 'Photos',
                    ),
                    Tab(
                      icon: Icon(Icons.video_library),
                      text: 'Videos',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              // Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: BouncingScrollPhysics(),
                  children: [
                    isPhotosLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.blue[700]))
                        : (photoList.isEmpty && !hasMorePhotos
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library,
                              size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No photos available',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                        : _buildListView(photoList, true)),
                    isVideosLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.blue[700]))
                        : (videoList.isEmpty && !hasMoreVideos
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library,
                              size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No videos available',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                        : _buildListView(videoList, false)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}