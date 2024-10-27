import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
class ImageSlider extends StatefulWidget {
  final List<dynamic> items;
  final double height;
  final bool isMainItem;
  final bool autoSlide;
  final Duration autoSlideDuration;
  final bool isAd;
  
  ImageSlider({
    required this.items,
    required this.height,
    this.isMainItem = false,
    this.autoSlide = false,
    this.autoSlideDuration = const Duration(seconds: 3),
    this.isAd = false,
  });

  @override
  _ImageSliderState createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoSlide) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(widget.autoSlideDuration, (timer) {
      if (_currentPage < widget.items.length - 1) {
        _pageController.nextPage(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return SizedBox(height: widget.height);

    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              if (widget.isAd) {
                final ad = widget.items[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: ad['imageUrl'] ?? 'https://via.placeholder.com/400x200',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) =>
                            Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(Icons.error),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ad['title'] ?? 'Advertisement',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (ad['description'] != null)
                                Text(
                                  ad['description'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return CachedNetworkImage(
                  imageUrl: widget.items[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                );
              }
            },
          ),
        ),
        if (widget.items.length > 1) ...[
          // Navigation buttons (only show when not in auto-slide mode)
          if (!widget.autoSlide) ...[
            if (_currentPage > 0)
              Positioned(
                left: 8,
                top: widget.height / 2 - 20,
                child: _buildNavigationButton(
                  icon: Icons.arrow_back_ios_new,
                  onPressed: () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            if (_currentPage < widget.items.length - 1)
              Positioned(
                right: 8,
                top: widget.height / 2 - 20,
                child: _buildNavigationButton(
                  icon: Icons.arrow_forward_ios,
                  onPressed: () {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
          ],
          // Enhanced page indicators
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length,
                (index) => _buildPageIndicator(index),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isActive = index == _currentPage;
    
    // Different styles for ads and regular images
    if (widget.isAd) {
      return GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          width: isActive ? 24 : 8,
          height: 8,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
              ? LinearGradient(
                  colors: [
                    Colors.blue,
                    Colors.purple,
                  ],
                )
              : null,
            color: isActive ? null : Colors.grey.withOpacity(0.5),
            boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
          ),
        ),
      );
    } else {
      // Original indicator style for regular images
      return AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 4),
        height: 8,
        width: isActive ? 24 : 8,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      );
    }
  }
}