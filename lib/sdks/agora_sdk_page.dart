import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraConfig {
  String? appId;
  String? token;
  String? channelId;
  String? userAccount;
  AgoraConfig({this.appId, this.token, this.channelId, this.userAccount});
}

class AgoraVideoCallScreen extends StatefulWidget {
  final AgoraConfig config;
  final Widget? title;
  final Future<bool> Function()? onCallEnd;

  const AgoraVideoCallScreen({
    super.key,
    required this.config,
    required this.onCallEnd,
    this.title,
  });

  @override
  State<AgoraVideoCallScreen> createState() => _AgoraVideoCallScreenState();
}

class _AgoraVideoCallScreenState extends State<AgoraVideoCallScreen>
    with TickerProviderStateMixin {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isCallActive = false;
  bool _isConnecting = true;
  bool _showControls = true;

  late AnimationController _controlsAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _pulseAnimation;

  Duration _callDuration = Duration.zero;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initAgora().catchError((error) {
      log('Failed to initialize Agora: $error');
      setState(() {
        _isConnecting = false;
      });
    });
    _startCallTimer();
  }

  void _initAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _controlsAnimationController.forward();
    _pulseAnimationController.repeat(reverse: true);
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((i) {
      if (mounted && _isCallActive) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime!);
        });
      }
    });
  }

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();

    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );

    if (!allGranted) {
      _showPermissionDialog();
      return false;
    }
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and microphone permissions are required for video calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _initAgora() async {
    try {
      bool hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        setState(() => _isConnecting = false);
        return;
      }

      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        RtcEngineContext(
          appId: widget.config.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _localUserJoined = true;
              _isCallActive = true;
              _isConnecting = false;
            });
            HapticFeedback.lightImpact();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUid = remoteUid;
              _isConnecting = false;
            });
            HapticFeedback.lightImpact();
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                setState(() => _remoteUid = null);
              },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                if (state == ConnectionStateType.connectionStateConnected) {
                  setState(() => _isConnecting = false);
                }
              },
          onError: (ErrorCodeType err, String msg) {
            log('Agora Error: $err - $msg');
            setState(() => _isConnecting = false);
          },
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));
      await _engine.enableVideo();
      await _engine.enableAudio();
      await _engine.startPreview();
      await _engine.joinChannelWithUserAccount(
        userAccount: widget.config.userAccount ?? "",
        token: widget.config.token ?? "",
        channelId: widget.config.channelId ?? "",
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      log('Error initializing Agora: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showEndCallConfirmation();

        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) {
              _controlsAnimationController.forward();
            } else {
              _controlsAnimationController.reverse();
            }
          },
          child: Stack(
            children: [
              _buildVideoBackground(),

              _buildTopBar(),

              _buildLocalVideoWindow(),

              _buildControlsOverlay(),

              if (_isConnecting) _buildConnectingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: _remoteUid != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.config.channelId),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade900, Colors.black],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Waiting for participant to join...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).padding.top + 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _showEndCallConfirmation(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.title ?? SizedBox(),
                      const SizedBox(height: 4),
                      Text(
                        _isCallActive
                            ? _formatCallDuration(_callDuration)
                            : _isConnecting
                            ? 'Connecting...'
                            : 'Call ended',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'speaker':
                        _toggleSpeaker();
                        break;
                      case 'info':
                        _showCallInfo();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'speaker',
                      child: Row(
                        children: [
                          Icon(
                            _isSpeakerEnabled
                                ? Icons.volume_up
                                : Icons.volume_down,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isSpeakerEnabled ? 'Speaker Off' : 'Speaker On',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Text('Call Info'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideoWindow() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      right: 16,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _localUserJoined
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 40 + MediaQuery.of(context).padding.bottom,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _controlsAnimation.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _controlsAnimation.value) * 50),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                      isActive: _isAudioEnabled,
                      onPressed: _toggleAudio,
                      backgroundColor: _isAudioEnabled
                          ? Colors.white.withOpacity(0.2)
                          : Colors.red,
                    ),

                    _buildControlButton(
                      icon: _isVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      isActive: _isVideoEnabled,
                      onPressed: _toggleVideo,
                      backgroundColor: _isVideoEnabled
                          ? Colors.white.withOpacity(0.2)
                          : Colors.red,
                    ),

                    _buildControlButton(
                      icon: _isSpeakerEnabled
                          ? Icons.volume_up
                          : Icons.volume_down,
                      isActive: _isSpeakerEnabled,
                      onPressed: _toggleSpeaker,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),

                    _buildControlButton(
                      icon: Icons.cameraswitch,
                      isActive: true,
                      onPressed: _switchCamera,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),

                    _buildControlButton(
                      icon: Icons.call_end,
                      isActive: false,
                      onPressed: _showEndCallConfirmation,
                      backgroundColor: Colors.red,
                      size: 60,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.4),
      ),
    );
  }

  Widget _buildConnectingOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please wait while we establish the connection',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAudio() async {
    setState(() => _isAudioEnabled = !_isAudioEnabled);
    await _engine.muteLocalAudioStream(!_isAudioEnabled);
  }

  void _toggleVideo() async {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    await _engine.muteLocalVideoStream(!_isVideoEnabled);
  }

  void _toggleSpeaker() async {
    setState(() => _isSpeakerEnabled = !_isSpeakerEnabled);
    await _engine.setEnableSpeakerphone(_isSpeakerEnabled);
  }

  void _switchCamera() async {
    await _engine.switchCamera();
  }

  Future<bool?> _showEndCallConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Call',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text('Are you sure you want to end this call?'),
        actions: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel"),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(true);
                    await _handleEndCall();
                  },
                  child: Text("End Call"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleEndCall() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _endCall();

      var response = widget.onCallEnd?.call();

      if (response is Future) {
        await response;
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      log('Error handling end call: $e');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text(
              'Failed to end call properly. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showCallInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Session ID', widget.config.channelId ?? ""),
            _buildInfoRow('Participant', "DEMO"),
            _buildInfoRow('Role', "DOCTOR"),
            _buildInfoRow('Duration', _formatCallDuration(_callDuration)),
            _buildInfoRow('Status', _isCallActive ? 'Active' : 'Connecting'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCallDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  Future _endCall() async {
    try {
      await _engine.leaveChannel();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      log('Error ending call: $e');
    }
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    _pulseAnimationController.dispose();
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      print('Error disposing engine: $e');
    }
  }
}
