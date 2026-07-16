import 'package:flutter/material.dart';

import 'benchmark_runner.dart';
import 'embedding_backend.dart';
import 'stage1_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Stage1App());
}

class Stage1App extends StatelessWidget {
  const Stage1App({super.key, this.autoRun = true});

  final bool autoRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memoyo Embedding Stage1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: BenchmarkScreen(autoRun: autoRun),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key, required this.autoRun});

  final bool autoRun;

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  String _status = 'Preparing stage1 benchmark…';
  bool _running = false;
  Stage1EmbeddingBackend? _backend;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = 'Loading config and verifying model hashes…';
    });
    Stage1Storage? storage;
    String? engine;
    try {
      await _backend?.close();
      _backend = null;
      storage = await Stage1Storage.open();
      final config = await storage.readConfig();
      engine = config.spec.id;
      setState(() => _status = 'Running ${config.spec.id}…');
      final execution = await BenchmarkRunner(storage: storage).run(config);
      _backend = execution.backend;
      final result = execution.result;
      if (!mounted) return;
      setState(() {
        _status =
            '${result.spec.id} complete\n'
            'load ${result.coldModelLoadMs} ms · '
            'cold ${result.coldFirstInferenceMs} ms · '
            'warm median '
            '${result.toJson()['warmInferenceMedianMs']} ms\n'
            '100 memo reindex ${result.reindex100Ms} ms · '
            '${result.dimensions}D';
      });
    } catch (error, stackTrace) {
      await storage?.writeState('failed', engine: engine);
      await storage?.writeCrash(error, stackTrace, engine: engine);
      await storage?.appendEvent('failed', engine: engine);
      if (!mounted) return;
      setState(() => _status = 'FAILED: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _backend?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memoyo embedding stage1 spike')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Experimental branch · not a production feature',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SelectableText(_status),
            const Spacer(),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Run again'),
            ),
          ],
        ),
      ),
    );
  }
}
