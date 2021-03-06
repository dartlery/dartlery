import 'dart:io';
import 'package:rpc/rpc.dart';
import 'package:test/test.dart';
import 'shared/api.dart';
import 'package:dartlery_shared/tools.dart';
import 'package:dartlery/data/data.dart';
import 'package:dartlery/server.dart';
import 'package:dartlery/api/gallery/gallery_api.dart';
import 'package:dartlery/api/api.dart';
import 'package:dartlery_shared/global.dart';

Server server;
GalleryApi get api => server.galleryApi;

Map<String, User> users;
void main() {
  CreateItemRequest request;

  setUp(() async {
    if (server != null) throw new Exception("Server already exists");

    server = await setUpServer();

    users = await createTestUsers(api);

    request = await createItemRequest();
  });

  tearDown(() async {
    await tearDownServer(server);
    server = null;
  });

  group("Item validation", () {});

  group("Method tests", () {
    test("create()", () async {
      expect(api.items.create(request.item), throwsNotImplementedException);
    }, skip: "Not quite working?");

    test("createItem()", () async {
      final IdResponse response = await api.items.createItem(request);
      validateIdResponse(response);
    });

    test("getById()", () async {
      final IdResponse response = await api.items.createItem(request);
      final Item item = await api.items.getById(response.id);
      expect(item, isNotNull);
    });

    test("update()", () async {
      final IdResponse response = await api.items.createItem(request);

      Item item = await api.items.getById(response.id);
      expect(item.tags.length, 3);

      final Tag newTag = new Tag.withValues("TestTagName");
      item.tags = <Tag>[newTag];

      await api.items.update(response.id, item);

      item = await api.items.getById(response.id);

      expect(item.tags.length, 1);
      expect(item.tags[0].id, newTag.id);
    });

    test("searchVisible()", () async {
      IdResponse response = await api.items.createItem(request);

      final Item item = await api.items.getById(response.id);
      expect(item.tags.length, 3);

      request = await createItemRequest(file: "test2.jpg");
      response = await api.items.createItem(request);

      final TagList searchTags = new TagList();
      searchTags.add(item.tags.first);

      PaginatedResponse<String> results =
          await api.items.searchVisible(searchTags.toJson());
      expect(results.items.length, 1);
      expect(results.items.first, item.id);

      searchTags.add(item.tags[2]);

      results = await api.items.searchVisible(searchTags.toJson());
      expect(results.items.length, 1);
      expect(results.items.first, item.id);
    });

    test("delete()", () async {
      final IdResponse response = await api.items.createItem(request);
      await api.items.delete(response.id);
      expect(api.items.getById(response.id), throwsNotFoundException);
    });
  });
}
