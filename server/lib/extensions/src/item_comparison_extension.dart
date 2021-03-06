import 'dart:async';
import 'dart:io';
import 'package:dartlery_shared/global.dart';
import 'package:dartlery/data/data.dart';
import 'package:dartlery/data_sources/data_sources.dart';
import 'package:dartlery/model/model.dart';
import 'package:dartlery/server.dart';
import 'package:dartlery_shared/global.dart';
import 'package:dartlery_shared/tools.dart';
import 'package:image/image.dart';
import 'package:image_hash/image_hash.dart';
import 'package:logging/logging.dart';
import 'package:option/option.dart';
import 'package:dartlery/services/background_service.dart';

import 'a_extension.dart';

class ItemComparisonExtension extends AExtension {
  static final Logger _log = new Logger('ItemComparisonPlugin');

  static const String pluginIdStatic = "itemComparison";

  static const int similarityCutoff = 88;

  static const String perceptualHashKeyName = "perceptualHash";
  static const String similarItemsKeyName = "similarItems";

  final AItemDataSource _itemDataSource;
  final ExtensionDataModel _extensionDataModel;
  final ABackgroundQueueDataSource _backgroundQueueDataSource;

  ItemComparisonExtension(this._itemDataSource, this._backgroundQueueDataSource,
      this._extensionDataModel);
  @override
  String get extensionId => pluginIdStatic;

  @override
  Future<Null> onBackgroundCycle(BackgroundQueueItem item) async {
    try {
      String itemId;
      DateTime startPoint;
      if (item.data is String) {
        if (item.data.contains(":")) {
          final int i = item.data.indexOf(":");
          itemId = item.data.substring(0, i);
          startPoint = DateTime.parse(item.data.substring(i + 1));
        } else {
          itemId = item.data;
        }
      } else if (item.data is Map) {
        itemId = item.data["itemId"];
        startPoint = item.data["lastProcessed"];
      }

      final Option<Item> sourceItem = await _itemDataSource.getById(itemId);

      if (sourceItem.isEmpty) return;

      if (!MimeTypes.imageTypes.contains(sourceItem.first.mime)) return;

      //if (startPoint == null) startPoint = sourceItem.first.uploaded;

      _log.fine("Checking for item $itemId starting with $startPoint");

      final ImageHash sourceHash = await _getPerceptualHash(itemId);

      if(sourceHash==null) {
        _log.warning("Start image does not have a perceptual hash, skipping");
        return;
      }

      final Stream<Item> itemStream = await _itemDataSource.streamAll(
          limit: 50, startDate: startPoint, addedDesc: true);
      DateTime lastProcessedDate;
      await for (Item targetItem in itemStream) {
        if(BackgroundService.stopping) {
          _log.warning("Backgorund services have stopper, exiting loop");
          break;
        }

        lastProcessedDate = targetItem.uploaded;
        if (sourceItem.first.id == targetItem.id) continue;
        if (!MimeTypes.imageTypes.contains(targetItem.mime)) continue;

        // We'll support comparing animated GIFs, but only to other animated GIFs
        if (sourceItem.first.video != targetItem.video) continue;

        try {
          if (await _checkForComparisonResult(
              sourceItem.first.id, targetItem.id)) continue;

          final ImageHash targetHash = await _getPerceptualHash(targetItem.id);

          final double result = sourceHash.compareTo(targetHash);

          if (result < similarityCutoff) continue;

          await _recordComparisonResult(
              sourceItem.first.id, targetItem.id, result);
        } catch (e, st) {
          _log.warning(e, st);
        }
      }
      if (lastProcessedDate != null) {
        _log.fine("Re-enqueing with new start point of $lastProcessedDate");
        final Map<String, dynamic> data = <String, dynamic>{};
        data["itemId"] = itemId;
        data["lastProcessed"] = lastProcessedDate;
        await _backgroundQueueDataSource.addToQueue(this.extensionId, data,
            priority: item.priority + 1);
      }
    } catch (e, st) {
      _log.severe(e, st);
    }
  }

  Future<Null> _deleteExtensionData(String itemId) async {
    try {
      await _extensionDataModel.delete(extensionId, perceptualHashKeyName,
          primaryId: itemId);
      await _extensionDataModel.deleteBidirectional(
          extensionId, similarItemsKeyName, itemId);
    } catch (e, st) {
      _log.warning(e, st);
    }
  }

  Future<Null> _enqueueBackgroundComparison(Item item) async {
    try {
      if (MimeTypes.imageTypes.contains(item.mime)) {
        await _backgroundQueueDataSource.addToQueue(this.extensionId, item.id,
            priority: 20);
      }
    } catch (e, st) {
      _log.severe("Error queueing image comparison for ${e.item.id}", e, st);
    }
  }

  @override
  Future<Null> onTrashingItem(String itemId) => _deleteExtensionData(itemId);

  @override
  Future<Null> onDeletingItem(String itemId) => _deleteExtensionData(itemId);

  // No longer auto-enqueueing. Unless drastic optimizations can happen,
  // the system currently can't handle the volume I'm throwing at it in a timely
  // manner. Will be switching to manually triggered, intentional comparisons.
  // Likely going to use a faster third-party program eventually.
  //@override
  //Future<Null> onCreatingItem(Item item) => _enqueueBackgroundComparison(item);

  @override
  Future<Null> onRestoringItem(String itemId) async {
    final Option<Item> item = await _itemDataSource.getById(itemId);
    if (item.isEmpty) throw new NotFoundException("Item not found: $itemId");
    await _enqueueBackgroundComparison(item.first);
  }

  Future<bool> _checkForComparisonResult(String itemId1, String itemId2) async {
    try {
      // TODO: Switch these to expects to save resources
      if (itemId1.compareTo(itemId2) < 0) {
        await _extensionDataModel.getSpecific(extensionId, similarItemsKeyName,
            primaryId: itemId1, secondaryId: itemId2);
      } else {
        await _extensionDataModel.getSpecific(extensionId, similarItemsKeyName,
            primaryId: itemId2, secondaryId: itemId1);
      }
      return true;
    } on NotFoundException {
      return false;
    }
  }

  Future<ImageHash> _getPerceptualHash(String imageID) async {
    try {
      final ExtensionData data = await _extensionDataModel
          .getSpecific(extensionId, perceptualHashKeyName, primaryId: imageID);
      if (data.value != null) {
        return new ImageHash.parse(data.value.toString());
      }
    } on NotFoundException {
      // Hash hasn't been generated, have to make it
    }
    final String fileName = getOriginalFilePathForHash(imageID);

    final File f = new File(fileName);
    if (!f.existsSync()) return null;

    final ImageHash imageHash =
        new ImageHash.forImage(decodeImage(f.readAsBytesSync()), size: 16);

    if(imageHash==null) {
      throw new Exception("Unable to generate image hash for item ID $imageID");
    }

    final String perceptualHash = imageHash.toString();
    _log.fine("Perceptual hash: $perceptualHash");

    final ExtensionData newData = new ExtensionData();
    newData.extensionId = extensionId;
    newData.key = perceptualHashKeyName;
    newData.primaryId = imageID;
    newData.value = perceptualHash;
    await _extensionDataModel.set(newData);

    return imageHash;
  }

  Future<Null> _recordComparisonResult(
      String itemId1, String itemId2, double result) async {
    final ExtensionData data = new ExtensionData();
    data.extensionId = extensionId;
    data.key = similarItemsKeyName;
    data.value = result;
    if (itemId1.compareTo(itemId2) < 0) {
      data.primaryId = itemId1;
      data.secondaryId = itemId2;
    } else {
      data.primaryId = itemId2;
      data.secondaryId = itemId1;
    }
    await _extensionDataModel.set(data);
  }
}
