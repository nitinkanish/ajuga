import 'package:aster/thermal/heat_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 30, 16);

  HeatSample sample(String state, HeatContext context, int minutes) {
    return HeatSample(at: t0.add(Duration(minutes: minutes)), state: state, context: context);
  }

  test('keeps a heat change and drops a repeat while Ajuga stays open', () {
    final first = sample('nominal', HeatContext.ajugaOpen, 0);
    final repeat = sample('nominal', HeatContext.whileAjugaOpen, 3);
    final hotter = sample('serious', HeatContext.stateChanged, 4);
    expect(shouldKeepHeatSample(first, repeat), isFalse);
    expect(shouldKeepHeatSample(first, hotter), isTrue);
    final log = appendHeatSample(appendHeatSample(const [], first), repeat);
    expect(log, hasLength(1));
    expect(appendHeatSample(log, hotter).first.state, 'serious');
  });

  test('keeps the level when leaving and returning, without duplicate leaves', () {
    final open = sample('nominal', HeatContext.ajugaOpen, 0);
    final left = sample('nominal', HeatContext.leftAjuga, 5);
    final leftAgain = sample('nominal', HeatContext.leftAjuga, 5);
    final back = sample('fair', HeatContext.returnedToAjuga, 20);
    expect(shouldKeepHeatSample(open, left), isTrue);
    expect(shouldKeepHeatSample(left, leftAgain), isFalse);
    expect(shouldKeepHeatSample(left, back), isTrue);
  });

  test('describes whether heat rose after leaving Ajuga', () {
    final samples = [
      sample('serious', HeatContext.returnedToAjuga, 30),
      sample('nominal', HeatContext.leftAjuga, 10),
    ];
    expect(awayHeatNote(samples), contains('Cool'));
    expect(awayHeatNote(samples), contains('Hot'));
    expect(awayHeatNote(samples), contains('does not name'));
    expect(
      awayHeatNote([
        sample('fair', HeatContext.returnedToAjuga, 30),
        sample('fair', HeatContext.leftAjuga, 10),
      ]),
      contains('still warm'),
    );
  });

  test('graph series keeps a temperature rise and explains load outside Ajuga', () {
    final start = DateTime(2026, 10, 30, 17);
    final points = appendSeries(const [], PhoneSnapshot(at: start, state: 'nominal', tempC: 31.2));
    final next = appendSeries(
      points,
      PhoneSnapshot(at: start.add(const Duration(seconds: 2)), state: 'nominal', tempC: 40),
    );
    expect(next, hasLength(1));
    final rising = appendSeries(
      next,
      PhoneSnapshot(
        at: start.add(const Duration(seconds: 10)),
        state: 'fair',
        tempC: 33.1,
        systemCpu: 0.62,
        ajugaCpu: 0.04,
        battery: 'charging',
      ),
    );
    expect(rising, hasLength(2));
    expect(temperatureChange(rising), closeTo(1.9, 0.01));
    final text = heatDiagnosis(rising.last, tempDelta: temperatureChange(rising));
    expect(text, contains('33.1°C'));
    expect(text, contains('charging'));
    expect(text, contains('did not reveal which app'));
    expect(text, contains('rose 1.9°C'));
  });

  test('names the other app with the highest measured processor use', () {
    final now = PhoneSnapshot(
      at: DateTime(2026, 10, 30, 17, 5),
      state: 'fair',
      tempC: 36.4,
      systemCpu: 0.55,
      ajugaCpu: 0.05,
      apps: const [
        AppLoad(name: 'Ajuga', cpu: 0.05, isAjuga: true),
        AppLoad(name: 'Safari', cpu: 0.72),
        AppLoad(name: 'Mail', cpu: 0.1),
      ],
    );
    expect(busiestOtherApp(now.apps)?.name, 'Safari');
    expect(heatDiagnosis(now), contains('36.4°C'));
    expect(heatDiagnosis(now), contains('Safari'));
  });

  test('rejects an impossible battery temperature', () {
    final reading = PhoneSnapshot.fromMap({'tempC': 250, 'state': 'nominal'});
    expect(reading.tempC, isNull);
    final sane = PhoneSnapshot.fromMap({'tempC': 32.5, 'state': 'nominal', 'systemCpu': 0.2});
    expect(sane.tempC, 32.5);
  });

  test('labels the four thermal levels without inventing a temperature', () {
    expect(heatLabel('nominal'), 'Cool');
    expect(heatLabel('fair'), 'Warm');
    expect(heatLabel('serious'), 'Hot');
    expect(heatLabel('critical'), 'Very hot');
    expect(heatMeaning('serious').toLowerCase(), isNot(contains('°')));
  });
}
