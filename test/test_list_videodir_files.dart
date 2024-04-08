import 'dart:io';

import 'package:csv/csv.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Diretório de trabalho do aplicativo
  final appDirectory = await getApplicationDocumentsDirectory();

  // Copiar arquivo de vídeo para o diretório de trabalho do aplicativo
  ByteData data =
      await rootBundle.load('assets/eyeblink8/9/27122013_152435_cam.avi');
  List<int> bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  String path = '${appDirectory.path}/eyeblink8_9.avi';
  await File(path).writeAsBytes(bytes);
  print('File copied to: $path');

  // Verifica se o diretório frames existe. Se não existir, cria o diretório.
  // Se existir, remove os arquivos do diretório.
  final frameDir = Directory('${appDirectory.path}/frames');
  if (!(await frameDir.exists())) {
    frameDir.create();
  } else {
    // Se o diretório tiver arquivos, tem que remover os arquivos...
    frameDir.deleteSync(recursive: true);
    frameDir.create();
  }
  print('Frames directory created: ${frameDir.path}');

  // Executar comando FFmpeg para extrair frames do vídeo
  var command = '-i ${appDirectory.path}/eyeblink8_9.avi '
      '-s 640x480 '
      '${appDirectory.path}/frames/out-%06d.png';
  var session = await FFmpegKit.execute(command);
  var returnCode = await session.getReturnCode();
  print('returnCode: $returnCode');
  var logs = await session.getLogs();
  for (final item in logs) {
    print('log: ${item.getMessage()}');
  }

  // Inicializa o detector de faces
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableContours: false,
      enableLandmarks: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Realiza um loop para listar os arquivos do diretório frames
  final framesDir = Directory('${appDirectory.path}/frames');
  int frame = 0;
  List<List<String>> dados = [];
  if (await framesDir.exists()) {
    List<FileSystemEntity> entities = await framesDir.list().toList();
    print('Frames directory');
    for (final e in entities) {
      print(e.path);
      final inputImage = InputImage.fromFilePath(e.path);
      final begin = DateTime.now();
      final faces = await faceDetector.processImage(inputImage);
      final detectionDuration = DateTime.now().difference(begin).inMilliseconds;
      print('Face detection duration: $detectionDuration ms');
      final fileName = e.path.split('/').last;
      List<String> linha = [
        '$frame',
        '$detectionDuration',
        '${faces.length}',
        fileName
      ];
      if (faces.isNotEmpty) {
        print(
            'Left eye open probability: ${faces.first.leftEyeOpenProbability}');
        linha.add('${faces.first.leftEyeOpenProbability}');
        linha.add('${faces.first.rightEyeOpenProbability}');
      } else {
        linha.add('0.0');
        linha.add('0.0');
      }
      dados.add(linha);
    }
  }

  String csv = const ListToCsvConverter().convert(dados);
  String dir = '${(await getExternalStorageDirectory())!.path}/documents';
  File f = File('$dir/filename.csv');
  f.writeAsString(csv);
}