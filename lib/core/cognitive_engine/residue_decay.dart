/// Attention residue decay model.
/// Dart port of @cognitrack/shared/src/residueDecay.ts
library;

import 'dart:math';
import 'constants.dart';

/// Exponential decay of attention residue over time.
/// R(dt) = residue * e^(-dt / tauMs)
/// At dt = 23 min: R ≈ 0.05 (5% residue = fully recovered)
double decayResidue(double residue, double deltaMs) {
  if (deltaMs <= 0) return residue;
  return residue * exp(-deltaMs / tauMs);
}

/// Apply a new context switch on top of existing (partially decayed) residue.
/// switchCost is the raw context distance value (1.0–9.0 scale).
/// New residue stacks on undecayed old residue — models unresolved prior task.
double applySwitch(
  double currentResidue,
  double timeSinceLastSwitchMs,
  double switchCost,
) {
  final decayed = decayResidue(currentResidue, timeSinceLastSwitchMs);
  // Normalise switchCost (max 9.0) to 0–1 contribution
  final newResidueFromSwitch = (switchCost / 9.0).clamp(0.0, 1.0);
  return (decayed + newResidueFromSwitch).clamp(0.0, 1.0);
}
