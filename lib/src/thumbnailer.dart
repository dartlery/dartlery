part of dartlery;

class Thumbnailer {
  static void createThumbnailForBits(String name, List<int> data) {
    io.Directory file_dir = new io.Directory(path.join(io.Directory.current.path,SettingsModel.STATIC_DIR,SettingsModel.THUMBS_DIR));
    if(!file_dir.existsSync()) {
      file_dir.createSync(recursive: true);
    }
    
    image.Image source_image = image.decodeImage(data);
    
    image.Image thumbnail;
    
    int new_height, new_width;
    
    if(source_image.width==source_image.height) {
      new_height = SettingsModel.thumbnailMaxDimension;
      new_width = SettingsModel.thumbnailMaxDimension;
    } else if(source_image.width>=source_image.height) {
      new_height = -1; // The image library has it's own internal auto-resize that mantains aspect ratio
      new_width = SettingsModel.thumbnailMaxDimension;
    } else {
      new_height = SettingsModel.thumbnailMaxDimension;
      double ratio = source_image.width / source_image.height;
      new_width = (SettingsModel.thumbnailMaxDimension * ratio).round();
    }
    
    thumbnail = image.copyResize(source_image,new_width,new_height,image.CUBIC);
    
    
    
    io.File thumb_file = new  io.File(path.join(file_dir.path,name));
    if(thumb_file.existsSync()) {
      thumb_file.deleteSync(recursive: false);
    }
    
    thumb_file.writeAsBytesSync(image.encodePng(thumbnail, level: 9));
  }
}