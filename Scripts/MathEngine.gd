extends Node
## Math problem generation and validation engine.
## Uses a deterministic custom LCG (SeededRNG) so both Godot client
## and Node.js server produce IDENTICAL problems from the same seed.

# ─── SeededRNG ────────────────────────────────────────────────────────────────
## Lehmer LCG matching the server-side JS implementation exactly.
class SeededRNG:
	var state: int

	func _init(seed_val: int) -> void:
		state = seed_val & 0x7FFFFFFF

	func next_int() -> int:
		state = (state * 1664525 + 1013904223) & 0x7FFFFFFF
		return state

	func randi_range(lo: int, hi: int) -> int:
		return lo + (next_int() % (hi - lo + 1))

	func randf() -> float:
		return float(next_int()) / float(0x7FFFFFFF)

# ─── Public API ───────────────────────────────────────────────────────────────

## Generate a problem dictionary from seed + tier.
## Returns: { question, answer, answer_str, display_type, [fraction_data] }
func generate(seed: int, tier: String = "pro") -> Dictionary:
	var rng := SeededRNG.new(seed)
	match tier.to_lower():
		"rookie":   return _gen_rookie(rng)
		"varsity":  return _gen_varsity(rng)
		"pro":      return _gen_pro(rng)
		"all_star": return _gen_all_star(rng)
		"mvp":      return _gen_mvp(rng)
	return _gen_pro(rng)

## Validate a player's submitted string answer against a problem dict.
func validate(submitted: String, problem: Dictionary) -> bool:
	submitted = submitted.strip_edges()
	var correct_str: String = problem.get("answer_str", "")

	if submitted == correct_str:
		return true

	# Numeric near-equality for decimals
	if submitted.is_valid_float() and correct_str.is_valid_float():
		return absf(float(submitted) - float(correct_str)) < 0.01

	# Fraction "N/D" input for fraction problems
	if "/" in submitted and problem.get("display_type", "") == "fraction":
		var parts := submitted.split("/")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var n := int(parts[0])
			var d := int(parts[1])
			if d != 0:
				return absf(float(n) / float(d) - float(problem.get("answer", 0.0))) < 0.01

	return false

## Suggest a tier adjustment based on match accuracy.
func adaptive_step(accuracy: float, tier: String) -> String:
	var order := ["rookie", "varsity", "pro", "all_star", "mvp"]
	var idx := order.find(tier.to_lower())
	if idx < 0: idx = 2
	if accuracy > 0.85 and idx < order.size() - 1:
		return order[idx + 1]
	elif accuracy < 0.50 and idx > 0:
		return order[idx - 1]
	return tier

## Quick sanity test — call from editor or at startup.
func run_self_test() -> bool:
	print("[MathEngine] Running self-test…")
	var tiers := ["rookie", "varsity", "pro", "all_star", "mvp"]
	for tier in tiers:
		for s in range(5):
			var prob := generate(s * 7919, tier)
			assert(prob.has("question"), "Missing 'question' in " + tier)
			assert(prob.has("answer_str"), "Missing 'answer_str' in " + tier)
			assert(validate(prob.answer_str, prob), "Self-validate failed: " + prob.question)
	print("[MathEngine] Self-test PASSED ✓")
	return true

# ─── Tier generators ──────────────────────────────────────────────────────────

func _gen_rookie(rng: SeededRNG) -> Dictionary:
	var a := rng.randi_range(1, 10)
	var b := rng.randi_range(1, 10)
	return _arith("%d + %d = ?" % [a, b], a + b)

func _gen_varsity(rng: SeededRNG) -> Dictionary:
	if rng.randi_range(0, 1) == 0:
		var a := rng.randi_range(10, 50)
		var b := rng.randi_range(10, 50)
		return _arith("%d + %d = ?" % [a, b], a + b)
	else:
		var a := rng.randi_range(20, 90)
		var b := rng.randi_range(1, a)
		return _arith("%d − %d = ?" % [a, b], a - b)

func _gen_pro(rng: SeededRNG) -> Dictionary:
	if rng.randi_range(0, 1) == 0:
		# Multiplication
		var a := rng.randi_range(2, 12)
		var b := rng.randi_range(2, 12)
		return _arith("%d × %d = ?" % [a, b], a * b)
	else:
		# Division — two formats alternated
		var divisor := rng.randi_range(2, 12)
		var quotient := rng.randi_range(2, 12)
		var dividend := divisor * quotient
		if rng.randi_range(0, 1) == 0:
			return _arith("%d ÷ %d = ?" % [dividend, divisor], quotient)
		else:
			return _arith("%d × ? = %d" % [divisor, dividend], quotient)

func _gen_all_star(rng: SeededRNG) -> Dictionary:
	match rng.randi_range(0, 2):
		0: return _gen_fraction_add(rng)
		1: return _gen_decimal_mult(rng)
		2: return _gen_mixed_ops(rng)
	return _gen_fraction_add(rng)

func _gen_mvp(rng: SeededRNG) -> Dictionary:
	# Simple linear equation: a + x = b
	var x := rng.randi_range(1, 20)
	var a := rng.randi_range(1, 10)
	return _arith("%d + x = %d" % [a, a + x], x)

# ─── Sub-generators ───────────────────────────────────────────────────────────

func _gen_fraction_add(rng: SeededRNG) -> Dictionary:
	var denoms: Array[int] = [2, 3, 4, 5, 6, 8, 10]
	var d: int = denoms[rng.randi_range(0, denoms.size() - 1)]
	var n1 := rng.randi_range(1, d - 1)
	var n2 := rng.randi_range(1, d - 1)
	var ans_n: int = n1 + n2
	var ans_d: int = d
	var g := _gcd(ans_n, ans_d)
	ans_n /= g
	ans_d /= g
	var ans_str := str(ans_n) if ans_d == 1 else ("%d/%d" % [ans_n, ans_d])
	return {
		"question": "%d/%d + %d/%d = ?" % [n1, d, n2, d],
		"answer": float(n1 + n2) / float(d),
		"answer_str": ans_str,
		"display_type": "fraction",
		"fraction_data": {"n1": n1, "d1": d, "n2": n2, "d2": d}
	}

func _gen_decimal_mult(rng: SeededRNG) -> Dictionary:
	var a := rng.randi_range(1, 9)
	var b := rng.randi_range(1, 9)
	var fa: float = a * 0.1
	var result: float = fa * b
	return _arith("%.1f × %d = ?" % [fa, b], result, "%.1f" % result)

func _gen_mixed_ops(rng: SeededRNG) -> Dictionary:
	var a := rng.randi_range(1, 9)
	var b := rng.randi_range(2, 9)
	var c := rng.randi_range(2, 9)
	return _arith("%d + %d × %d = ?" % [a, b, c], a + b * c)

# ─── Utilities ────────────────────────────────────────────────────────────────

func _arith(question: String, answer: Variant, answer_str: String = "") -> Dictionary:
	var s := answer_str if answer_str != "" else str(answer)
	return {
		"question": question,
		"answer": answer,
		"answer_str": s,
		"display_type": "arithmetic"
	}

func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return abs(a)
