library google_places_flutter;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'model/place_details.dart';
import 'model/place_type.dart';
import 'model/prediction.dart';
import 'package:rxdart/rxdart.dart';

import 'dio_error_handler.dart';

// ignore: must_be_immutable
class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  InputDecoration inputDecoration;
  ItemClick? itemClick;
  GetPlaceDetailswWithLatLng? getPlaceDetailWithLatLng;
  bool isLatLngRequired = true;

  TextStyle textStyle;
  String googleAPIKey;
  int debounceTime = 600;
  List<String>? countries = [];
  TextEditingController textEditingController = TextEditingController();
  ListItemBuilder? itemBuilder;
  Widget? seperatedBuilder;
  void clearData;
  BoxDecoration? boxDecoration;
  bool isCrossBtnShown;
  bool showError;
  double? containerHorizontalPadding;
  double? containerVerticalPadding;
  FocusNode? focusNode;
  PlaceType? placeType;
  String? language;

  GooglePlaceAutoCompleteTextField({
    Key? key,
    required this.textEditingController,
    required this.googleAPIKey,
    this.debounceTime = 600,
    this.inputDecoration = const InputDecoration(),
    this.itemClick,
    this.isLatLngRequired = true,
    this.textStyle = const TextStyle(),
    this.countries,
    this.getPlaceDetailWithLatLng,
    this.itemBuilder,
    this.boxDecoration,
    this.isCrossBtnShown = true,
    this.seperatedBuilder,
    this.showError = true,
    this.containerHorizontalPadding,
    this.containerVerticalPadding,
    this.focusNode,
    this.placeType,
    this.language = 'en',
  }) : super(key: key);

  @override
  GooglePlaceAutoCompleteTextFieldState createState() =>
      GooglePlaceAutoCompleteTextFieldState();
}

class GooglePlaceAutoCompleteTextFieldState
    extends State<GooglePlaceAutoCompleteTextField> {
  final subject = PublishSubject<String>();
  OverlayEntry? _overlayEntry;
  List<Prediction> alPredictions = [];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  bool isCrossBtn = true;
  late Dio _dio;

  CancelToken? _cancelToken = CancelToken();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.containerHorizontalPadding ?? 0,
          vertical: widget.containerVerticalPadding ?? 0,
        ),
        alignment: Alignment.centerLeft,
        decoration: widget.boxDecoration ??
            BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.grey, width: 0.6),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                decoration: widget.inputDecoration,
                style: widget.textStyle,
                controller: widget.textEditingController,
                focusNode: widget.focusNode ?? FocusNode(),
                onChanged: (string) {
                  subject.add(string);
                  if (widget.isCrossBtnShown) {
                    isCrossBtn = string.isNotEmpty ? true : false;
                    setState(() {});
                  }
                },
              ),
            ),
            (!widget.isCrossBtnShown)
                ? const SizedBox()
                : isCrossBtn && _showCrossIconWidget()
                    ? IconButton(
                        onPressed: clearData,
                        icon: const Icon(Icons.close),
                      )
                    : const SizedBox(),
          ],
        ),
      ),
    );
  }

  getLocation(String text) async {
    String apiURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=${widget.googleAPIKey}&language=${widget.language}';

    if (widget.countries != null) {
      // in

      for (int i = 0; i < widget.countries!.length; i++) {
        String country = widget.countries![i];

        if (i == 0) {
          apiURL = '$apiURL&components=country:$country';
        } else {
          apiURL = '$apiURL|country:$country';
        }
      }
    }
    if (widget.placeType != null) {
      apiURL += '&types=${widget.placeType?.apiString}';
    }

    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
      _cancelToken = CancelToken();
    }

    try {
      String proxyURL = 'https://cors-anywhere.herokuapp.com/';
      String url = kIsWeb ? proxyURL + apiURL : apiURL;

      Response response = await _dio.get(url);
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      Map map = response.data;
      if (map.containsKey('error_message')) {
        throw response.data;
      }

      PlacesAutocompleteResponse subscriptionResponse =
          PlacesAutocompleteResponse.fromJson(response.data);

      if (text.isEmpty) {
        alPredictions.clear();
        _overlayEntry!.remove();
        return;
      }

      isSearched = false;
      alPredictions.clear();
      if (subscriptionResponse.predictions!.isNotEmpty &&
          (widget.textEditingController.text.toString().trim()).isNotEmpty) {
        alPredictions.addAll(subscriptionResponse.predictions!);
      }

      _overlayEntry = null;
      _overlayEntry = _createOverlayEntry();
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        Overlay.of(context).insert(_overlayEntry!);
      }
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      _showSnackBar('${errorHandler.message}');
    }
  }

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  textChanged(String text) async {
    getLocation(text);
  }

  OverlayEntry? _createOverlayEntry() {
    if (context.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
        builder: (context) => Positioned(
          left: offset.dx,
          top: size.height + offset.dy,
          width: size.width,
          child: CompositedTransformFollower(
            showWhenUnlinked: false,
            link: _layerLink,
            offset: Offset(0.0, size.height + 5.0),
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: alPredictions.length,
                separatorBuilder: (context, pos) =>
                    widget.seperatedBuilder ?? const SizedBox(),
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                    onTap: () {
                      var selectedData = alPredictions[index];
                      if (index < alPredictions.length) {
                        widget.itemClick!(selectedData);

                        if (widget.isLatLngRequired) {
                          getPlaceDetailsFromPlaceId(selectedData);
                        }
                        removeOverlay();
                      }
                    },
                    child: widget.itemBuilder != null
                        ? widget.itemBuilder!(
                            context,
                            index,
                            alPredictions[index],
                          )
                        : Container(
                            padding: const EdgeInsets.all(10),
                            child: Text(alPredictions[index].description!),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  removeOverlay() {
    alPredictions.clear();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _overlayEntry!.markNeedsBuild();
  }

  Future<Response?> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    //String key = GlobalConfiguration().getString('google_maps_key');

    var url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction.placeId}&key=${widget.googleAPIKey}';
    try {
      Response response = await _dio.get(
        url,
      );

      PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);

      prediction.lat = placeDetails.result!.geometry!.location!.lat.toString();
      prediction.lng = placeDetails.result!.geometry!.location!.lng.toString();

      widget.getPlaceDetailWithLatLng!(prediction);
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      _showSnackBar('${errorHandler.message}');
    }
    return null;
  }

  void clearData() {
    widget.textEditingController.clear();
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
    }

    setState(() {
      alPredictions.clear();
      isCrossBtn = false;
    });

    if (_overlayEntry != null) {
      try {
        _overlayEntry?.remove();
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  _showCrossIconWidget() {
    return (widget.textEditingController.text.isNotEmpty);
  }

  _showSnackBar(String errorData) {
    if (widget.showError) {
      final snackBar = SnackBar(
        content: Text(errorData),
      );

      // Find the ScaffoldMessenger in the widget tree
      // and use it to show a SnackBar.
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
}

PlacesAutocompleteResponse parseResponse(Map responseBody) {
  return PlacesAutocompleteResponse.fromJson(
    responseBody as Map<String, dynamic>,
  );
}

PlaceDetails parsePlaceDetailMap(Map responseBody) {
  return PlaceDetails.fromJson(responseBody as Map<String, dynamic>);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
  Prediction postalCodeResponse,
);

typedef ListItemBuilder = Widget Function(
  BuildContext context,
  int index,
  Prediction prediction,
);
