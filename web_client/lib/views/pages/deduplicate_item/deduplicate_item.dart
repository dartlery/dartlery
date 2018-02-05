import 'dart:async';

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_image_compare/image_compare_component.dart';
import 'package:angular_router/angular_router.dart';
import 'package:dartlery/api/api.dart';
import 'package:dartlery/data/data.dart';
import 'package:dartlery/routes.dart';
import 'package:dartlery/services/services.dart';
import 'package:dartlery/views/controls/auth_status_component.dart';
import 'package:dartlery/views/controls/common_controls.dart';
import 'package:dartlery/views/controls/error_output.dart';
import 'package:dartlery_shared/global.dart';
import 'package:dartlery_shared/tools.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import '../src/deduplicate_shared.dart';
import '../src/a_page.dart';

@Component(
    selector: 'deduplicate-item-page',
    providers: const <dynamic>[materialProviders],
    directives: const <dynamic>[
      CORE_DIRECTIVES,
      materialDirectives,
      ROUTER_DIRECTIVES,
      AuthStatusComponent,
      ErrorOutputComponent,
      ImageCompareComponent,
      commonControls,
      NgClass,
    ],
    styleUrls: const <String>["../../shared.css", "deduplicate_item.css"],
    templateUrl: "deduplicate_item.html")
class DeduplicateItemPage extends APage implements OnInit, OnDestroy {
  static final Logger _log = new Logger("DeduplicateItemPage");

  static const PageAction _animatePageAction =
      const PageAction("animate", "av_timer");

  static const PageAction _removeAction =
      const PageAction("remove", "remove_circle", true);
  String currentItemId;

  ExtensionData model;

  Item firstComparisonItem = new Item();

  Item secondComparisonItem = new Item();

  List<ExtensionData> otherComparisons = <ExtensionData>[];

  int currentImage = 0;
  bool splitComparison = false;

  ApiService _api;

  Router _router;
  AuthenticationService _auth;
  Location _location;
  RouteParams _params;

  StreamSubscription<PageAction> _pageActionSubscription;

  final NumberFormat f = new NumberFormat.decimalPattern();

  // TODO: Learn how to use this animate class for this: https://github.com/dart-lang/angular_components/blob/master/lib/src/components/material_progress/material_progress.dart

  bool animatedComparison = true;

  TagList differentTags = new TagList();

  int totalItems = 0;

  DeduplicateItemPage(PageControlService pageControl, this._api, this._auth,
      this._router, this._params, this._location)
      : super(_auth, _router, pageControl) {
    pageControl.setPageTitle("Deduplicate");
  }

  int get firstComparisonPixelCount =>
      (firstComparisonItem?.height ?? 0) * (firstComparisonItem?.width ?? 0);

  int get firstLength => int.parse(firstComparisonItem?.length ?? "0");

  int get lengthWinner {
    if (firstLength > secondLength) {
      return 0;
    } else if (firstLength < secondLength) {
      return 1;
    }
    return -1;
  }

  @override
  Logger get loggerImpl => _log;

  int get secondComparisonPixelCount =>
      (secondComparisonItem?.height ?? 0) * (secondComparisonItem?.width ?? 0);

  int get secondLength => int.parse(secondComparisonItem?.length ?? "0");

  int get sizeWinner {
    if (firstComparisonPixelCount > secondComparisonPixelCount) {
      return 0;
    } else if (firstComparisonPixelCount < secondComparisonPixelCount) {
      return 1;
    }
    return -1;
  }

  void clear() {
    currentItemId = "";
    model = null;
    firstComparisonItem = new Item();
    secondComparisonItem = new Item();
    otherComparisons.clear();
    differentTags.clear();
  }

  Future<Null> clearAll([List<ExtensionData> toClear = null]) async {
    pageControl.setIndeterminateProgress();
    List<ExtensionData> itemsToRemove = toClear ?? otherComparisons;
    await performApiCall(() async {
      int i = 1;
      final int total = itemsToRemove.length;
      pageControl.setProgress(0, max: total);
      while (itemsToRemove.isNotEmpty) {
        final ExtensionData data = itemsToRemove[0];
        await _api.extensionData.delete(
            "itemComparison", "similarItems", data.primaryId, data.secondaryId);
        itemsToRemove.removeAt(0);
        pageControl.setProgress(i, max: total);
        i++;
      }
      await refresh();
    });
  }

  Future<Null> clearSimilarity(ExtensionData data) async {
    pageControl.setIndeterminateProgress();
    await performApiCall(() async {
      await _api.extensionData.delete(
          "itemComparison", "similarItems", data.primaryId, data.secondaryId);
    });
    await refresh();
  }

  Future<Null> deleteAll([List<ExtensionData> toClear = null]) async {
    pageControl.setIndeterminateProgress();
    List<ExtensionData> itemsToRemove = toClear ?? otherComparisons;

    await performApiCall(() async {
      int i = 1;
      final int total = itemsToRemove.length;
      pageControl.setProgress(0, max: total);
      while (itemsToRemove.isNotEmpty) {
        final ExtensionData data = itemsToRemove[0];

        final String toDelete = getOtherImageId(data);

        if (isNotNullOrWhitespace(toDelete)) {
          await _api.items.delete(toDelete);
        }

        itemsToRemove.removeAt(0);
        pageControl.setProgress(i, max: total + 1);
        i++;
      }
      await _api.items.delete(this.currentItemId);
      pageControl.setProgress(total + 1, max: total + 1);

      await refresh();
    });
  }

  Future<Null> deleteItem(String id) async {
    pageControl.setIndeterminateProgress();
    await performApiCall(() async {
      await _api.items.delete(id);

      if (id == currentItemId) currentItemId == "";
    });
    await refresh();
  }

  String getOtherImageId(ExtensionData data) => DeduplicateShared.getOtherImageId(currentItemId, data);

  Future<Null> mergeItems(String sourceId, String targetId,
      {bool refresh: true}) async {
    pageControl.setIndeterminateProgress();
    await performApiCall(() async {
      final IdRequest request = new IdRequest();
      request.id = sourceId;
      await _api.items.mergeItems(request, targetId);
      if (sourceId == currentItemId) currentItemId == "";
    }, after: () async {
      pageControl.clearProgress();
    });
    if (refresh) await this.refresh();
  }

  @override
  void ngOnDestroy() {
    _pageActionSubscription?.cancel();
  }

  @override
  void ngOnInit() {
    final String _id = _params.get(idRouteParameter);
    currentItemId = _id;

    setPageActions();

    _pageActionSubscription =
        pageControl.pageActionRequested.listen(onPageActionRequested);
    refresh();
  }

  void onPageActionRequested(PageAction action) {
    switch (action) {
      case PageAction.refresh:
        this.refresh();
        break;
      case PageAction.compare:
        splitComparison = !splitComparison;
        break;
      case _animatePageAction:
        animatedComparison = !animatedComparison;
        break;
      case _removeAction:
        clearAll();
        break;
      case PageAction.delete:
        deleteAll();
        break;
      default:
        throw new Exception(
            action.toString() + " not implemented for this page");
    }
  }

  Future<Null> refresh() async {
    pageControl.setIndeterminateProgress();
    PaginatedExtensionDataResponse response;
    await performApiCall(() async {
      try {
        if (isNotNullOrWhitespace(currentItemId)) {
          final String currentItemId = this.currentItemId;
          response = await _api.extensionData.getByPrimaryId(
              "itemComparison", "similarItems", currentItemId,
              bidirectional: true,
              orderByValues: true,
              orderDescending: true,
              perPage: 100);
          clear();
          if (response.items.isNotEmpty) {
            this.currentItemId = currentItemId;
            otherComparisons = response.items;
            await selectComparison(response.items.first);
            return;
          }
        }
      } on DetailedApiRequestError catch (e) {
        if (e.status != 404) throw e;
      }

      try {
        clear();
        response = await _api.extensionData.get(
            "itemComparison", "similarItems",
            orderDescending: false, perPage: 1);
        if (response.items.isNotEmpty) {
          totalItems = response.totalCount;

          currentItemId = response.items.first.primaryId;
          response = await _api.extensionData.getByPrimaryId(
              "itemComparison", "similarItems", currentItemId,
              bidirectional: true,
              orderByValues: true,
              orderDescending: true,
              perPage: 100);
          otherComparisons = response.items;
          await selectComparison(response.items.first);
        }
      } on DetailedApiRequestError catch (e) {
        if (e.status != 404) throw e;
      }
    }, after: () async {
      pageControl.clearProgress();
    });
  }

  Future<Null> selectComparison(ExtensionData ed) async {
    pageControl.setIndeterminateProgress();
    await performApiCall(() async {
      model = ed;

      if (isNotNullOrWhitespace(currentItemId)) {
        firstComparisonItem = await _api.items.getById(currentItemId);
        secondComparisonItem = await _api.items.getById(getOtherImageId(ed));
      } else {
        firstComparisonItem = await _api.items.getById(model.primaryId);
        secondComparisonItem = await _api.items.getById(model.secondaryId);
      }
      final Diff<TagWrapper> tagDiff = new Diff<TagWrapper>(
          firstComparisonItem.tags.map((Tag t) => new TagWrapper.fromTag(t)),
          secondComparisonItem.tags.map((Tag t) => new TagWrapper.fromTag(t)));
      differentTags.clear();
      differentTags.addAll(tagDiff.different);
    }, after: () async {
      pageControl.clearProgress();
      setPageActions();
    });
  }

  Future<Null> selectItem(String id) async {
    this.currentItemId = id;
    await refresh();
  }

  setPageActions() {
    final List<PageAction> actions = <PageAction>[];

      actions.add(PageAction.compare);
      actions.add(_animatePageAction);
      actions.add(PageAction.delete);
      actions.add(_removeAction);
    actions.add(PageAction.refresh);

    pageControl.setAvailablePageActions(actions);
  }
}