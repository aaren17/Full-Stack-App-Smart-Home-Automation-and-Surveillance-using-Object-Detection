import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'cctv_details.dart';

// WebView Controller class for maintaining state
class CCTVWebViewController {
  InAppWebViewController? controller;
  final String url;
  bool isInitialized = false;

  CCTVWebViewController(this.url);
}

class CCTVPage extends StatefulWidget {
  const CCTVPage({Key? key}) : super(key: key);

  @override
  _CCTVPageState createState() => _CCTVPageState();
}

class _CCTVPageState extends State<CCTVPage> {
  final TextEditingController _ipController = TextEditingController(text: '10.115.29.241:8889');
  String _currentIp = '10.115.29.241:8889';
  final Map<String, CCTVWebViewController> _webViewControllers = {};

  final List<Map<String, dynamic>> cameras = [
    {
      'name': 'Camera 1',
      'path': '/cam1/',
      'isLive': false,
      'id': '1'
    },
    {
      'name': 'Camera 2',
      'path': '/cam2/',
      'isLive': false,
      'id': '2'
    },
  ];

  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebViewControllers();
    _statusTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkCameraStatus();
    });
    _checkCameraStatus();
  }

  void _initializeWebViewControllers() {
    for (var camera in cameras) {
      final url = 'http://$_currentIp${camera['path']}';
      _webViewControllers[camera['id']] = CCTVWebViewController(url);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _showIpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set IP Address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  hintText: 'xxx.xxx.xxx.xxx:port',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentIp = _ipController.text;
                        // Reinitialize controllers with new IP
                        _initializeWebViewControllers();
                      });
                      Navigator.pop(context);
                      _checkCameraStatus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkCameraStatus() async {
    for (int i = 0; i < cameras.length; i++) {
      try {
        final url = 'http://$_currentIp${cameras[i]['path']}';
        final response = await http.get(Uri.parse(url))
            .timeout(Duration(seconds: 5));
        setState(() {
          cameras[i]['isLive'] = response.statusCode == 200;
        });
      } catch (e) {
        setState(() {
          cameras[i]['isLive'] = false;
        });
      }
    }
  }

  void _showAddDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Camera',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Camera Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.videocam),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: InputDecoration(
                  labelText: 'Camera Path',
                  hintText: '/cam3/',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (pathController.text.isNotEmpty) {
                        setState(() {
                          String newId = '${cameras.length + 1}';
                          cameras.add({
                            'name': nameController.text.isEmpty
                                ? 'Camera $newId'
                                : nameController.text,
                            'path': pathController.text,
                            'isLive': false,
                            'id': newId,
                          });
                          // Initialize controller for new camera
                          final url = 'http://$_currentIp${pathController.text}';
                          _webViewControllers[newId] = CCTVWebViewController(url);
                        });
                        Navigator.pop(context);
                        _checkCameraStatus();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Add Camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(int index) {
    final TextEditingController nameController = TextEditingController(text: cameras[index]['name']);
    final TextEditingController pathController = TextEditingController(text: cameras[index]['path']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Camera',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Camera Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.videocam),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: InputDecoration(
                  labelText: 'Camera Path',
                  hintText: '/cam1/',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (pathController.text.isNotEmpty) {
                        setState(() {
                          cameras[index]['name'] = nameController.text;
                          cameras[index]['path'] = pathController.text;
                          // Update controller for edited camera
                          final url = 'http://$_currentIp${pathController.text}';
                          _webViewControllers[cameras[index]['id']] = CCTVWebViewController(url);
                        });
                        Navigator.pop(context);
                        _checkCameraStatus();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Camera"),
          content: Text("Are you sure you want to delete ${cameras[index]['name']}?"),
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
                setState(() {
                  // Remove the controller when deleting camera
                  _webViewControllers.remove(cameras[index]['id']);
                  cameras.removeAt(index);
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraCard(Map<String, dynamic> camera, int index) {
    final String fullUrl = 'http://$_currentIp${camera['path']}';
    final webViewController = _webViewControllers[camera['id']]!;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CCTVDetails(
            cameraUrl: fullUrl,
            cameraName: camera['name']!,
            cameraId: camera['id']!,
            webViewController: webViewController,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: camera['isLive']
                    ? AbsorbPointer(
                  absorbing: true,
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(fullUrl),
                    ),
                    onWebViewCreated: (controller) {
                      webViewController.controller = controller;
                      webViewController.isInitialized = true;
                    },
                    initialSettings: InAppWebViewSettings(
                      disableContextMenu: true,
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: false,
                      supportZoom: false,
                      useHybridComposition: true,
                    ),
                  ),
                )
                    : Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          color: Colors.white54,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _showEditDialog(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _showDeleteConfirmation(index),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        camera['name']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: camera['isLive'] ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            camera['isLive'] ? 'Live Feed' : 'Offline',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: camera['isLive']
                        ? Colors.green.withOpacity(0.9)
                        : Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
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
                      SizedBox(width: 4),
                      Text(
                        camera['isLive'] ? 'LIVE' : 'OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'CCTV Viewer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.wifi, color: Colors.white),
            onPressed: _showIpDialog,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showAddDialog,
          ),
          SizedBox(width: 8),
        ],
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
        child: SafeArea(
          child: GridView.builder(
            padding: EdgeInsets.all(20),
            physics: BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 3/4,
            ),
            itemCount: cameras.length,
            itemBuilder: (context, index) => _buildCameraCard(cameras[index], index),
          ),
        ),
      ),
    );
  }
}