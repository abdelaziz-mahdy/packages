import 'dart:io';
import 'dart:math';

class Caption {
  const Caption({
    required this.start,
    required this.end,
    required this.text,
  });
  final Duration start;
  final Duration end;
  final String text;
}

// Linear search lookup
Caption linearLookup(List<Caption> captions, Duration position) {
  for (final Caption caption in captions) {
    if (caption.start <= position && caption.end >= position) {
      return caption;
    }
  }
  return const Caption(start: Duration.zero, end: Duration.zero, text: '');
}

// Binary search lookup (captions must be sorted by start)
Caption binaryLookup(List<Caption> captions, Duration position) {
  int left = 0;
  int right = captions.length - 1;
  while (left <= right) {
    final int mid = left + ((right - left) >> 1);
    final Caption c = captions[mid];
    if (position < c.start) {
      right = mid - 1;
    } else if (position > c.end) {
      left = mid + 1;
    } else {
      return c;
    }
  }
  return const Caption(start: Duration.zero, end: Duration.zero, text: '');
}

void printStats(String label, List<int> times) {
  times.sort();
  final int min = times.first;
  final int max = times.last;
  final double median = times.length % 2 == 1
      ? times[times.length ~/ 2].toDouble()
      : (times[times.length ~/ 2 - 1] + times[times.length ~/ 2]) / 2.0;
  final int p90 = times[(times.length * 0.9).floor()];
  final int p99 = times[(times.length * 0.99).floor()];
  final double avg = times.reduce((int a, int b) => a + b) / times.length;
  print('$label:');
  print('  min:    $min µs');
  print('  max:    $max µs');
  print('  median: ${median.toStringAsFixed(2)} µs');
  print('  p90:    $p90 µs');
  print('  p99:    $p99 µs');
  print('  avg:    ${avg.toStringAsFixed(2)} µs');
}

void main() {
  const int numCaptions = 10000000;
  const int captionDurationSeconds = 1;
  const int numLookups = 10000;
  final Random random = Random(42);

  // Generate synthetic captions
  final List<Caption> captions = List.generate(numCaptions, (int i) {
    final Duration start = Duration(seconds: i * captionDurationSeconds);
    final Duration end =
        Duration(seconds: (i + 1) * captionDurationSeconds - 1);
    return Caption(
      start: start,
      end: end,
      text: 'Caption $i',
    );
  });

  // Shuffle for unsorted test (for linear search)
  final List<Caption> unsortedCaptions = List.of(captions);
  unsortedCaptions.shuffle(random);

  // Measure memory after unsorted list
  int memUnsorted = 0;
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    memUnsorted = ProcessInfo.currentRss;
  }

  // Sorted for binary search
  final List<Caption> sortedCaptions = List.of(captions);
  sortedCaptions.sort((Caption a, Caption b) => a.start.compareTo(b.start));

  // Measure memory after sorted list
  int memSorted = 0;
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    memSorted = ProcessInfo.currentRss;
  }

  // Generate random lookup positions
  final List<Duration> lookupPositions = List.generate(numLookups, (_) {
    final int sec = random.nextInt(numCaptions * captionDurationSeconds);
    return Duration(seconds: sec);
  });

  // Warm up
  for (final Duration pos in lookupPositions.take(100)) {
    linearLookup(unsortedCaptions, pos);
    binaryLookup(sortedCaptions, pos);
  }

  // Benchmark linear search (collect times)
  final List<int> linearTimes = <int>[];
  for (final Duration pos in lookupPositions) {
    final Stopwatch sw = Stopwatch()..start();
    linearLookup(unsortedCaptions, pos);
    sw.stop();
    linearTimes.add(sw.elapsedMicroseconds);
  }

  // Benchmark binary search (collect times)
  final List<int> binaryTimes = <int>[];
  for (final Duration pos in lookupPositions) {
    final Stopwatch sw = Stopwatch()..start();
    binaryLookup(sortedCaptions, pos);
    sw.stop();
    binaryTimes.add(sw.elapsedMicroseconds);
  }

  print('--- Caption Lookup Benchmark ---');
  print('Captions: $numCaptions');
  print('Lookups: $numLookups');

  printStats('Linear search', linearTimes);
  printStats('Binary search', binaryTimes);

  if (memUnsorted > 0 && memSorted > 0) {
    print('--- Memory Usage ---');
    print(
        'Unsorted captions only: ${(memUnsorted / (1024 * 1024)).toStringAsFixed(2)} MB');
    print(
        'With sorted captions:   ${(memSorted / (1024 * 1024)).toStringAsFixed(2)} MB');
    print(
        'Delta (sorted array):  ${((memSorted - memUnsorted) / (1024 * 1024)).toStringAsFixed(2)} MB');
  }
}
