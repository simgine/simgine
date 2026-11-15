extends TestSuite


func test_assert() -> void:
	assert_eq(1, 1)
	assert_ne(1, 2)
	assert_eq(1.0, 1.0)
	assert_ne(1.0, 1.0000001)


func test_assert_arrays() -> void:
	assert_eq([1, 2], [1, 2])
	assert_ne([1, 2], [1, 3])
	assert_ne([1, 2], [1])
	assert_ne([1], 1)
	assert_ne(1, [1])

	assert_eq([1, 2], [1, 2] as Array[int])
	assert_eq(PackedInt32Array([1, 2]), [1, 2])
	assert_eq([1, 2], PackedInt32Array([1, 2]))
	assert_eq([], PackedInt32Array())
	assert_ne(PackedInt32Array([1]), 1)
	assert_ne(1, PackedInt32Array([1]))


func test_assert_nested_arrays() -> void:
	assert_eq([[1, 2], ["item"]], [[1, 2], ["item"]])
	assert_eq([[1, 2], ["item"]], [PackedInt32Array([1, 2]), PackedStringArray(["item"])])
	assert_ne([[1], [2]], [[1], [3]])


func test_assert_approx() -> void:
	assert_approx_eq(1.0, 1.0000001)
	assert_approx_ne(1.0, 1.00001)
	assert_approx_eq(100.0, 100.01, 0.001)
	assert_approx_ne(100.0, 100.01)
	assert_approx_eq(Vector3.ONE, Vector3(1.0000001, 1, 1))
	assert_approx_ne(Vector3.ONE, Vector3(1.00001, 1, 1))


func test_assert_approx_bases() -> void:
	var basis := Basis(Vector3(2, 0, 0), Vector3(0, 3, 0), Vector3(0, 0, 4))
	var nearby := basis
	nearby.x.x += 0.0000001
	nearby.y.y += 0.0000001
	nearby.z.z += 0.0000001
	assert_approx_eq(basis, nearby)
	assert_approx_eq([basis], [nearby])

	for axis in 3:
		var changed := basis
		changed[axis] *= 1.001
		assert_approx_ne(basis, changed, 1e-6)
		assert_approx_eq(basis, changed, 0.01)

	var invalid := basis
	invalid.x.x = NAN
	assert_approx_ne(invalid, invalid)
	assert_approx_ne(basis, Vector3.ONE)
	assert_approx_ne(Vector3.ONE, basis)


func test_assert_approx_transforms() -> void:
	var transform := Transform3D(Basis.IDENTITY, Vector3(100, 200, 300))
	var nearby := transform
	nearby.origin.x += 0.0000001
	nearby.basis.x.x += 0.0000001
	assert_approx_eq(transform, nearby)
	assert_approx_eq([transform], [nearby])

	var translated := transform
	translated.origin.x += 1.0
	assert_approx_ne(transform, translated)
	assert_approx_eq(transform, translated, 0.01)

	var scaled := transform
	scaled.basis.x *= 1.00001
	assert_approx_ne(transform, scaled, 1e-6, "a large origin must not hide a basis difference")
	assert_approx_eq(transform, scaled, 0.001)
	assert_approx_ne(transform, transform.basis)
	assert_approx_ne(transform.basis, transform)


func test_assert_approx_arrays() -> void:
	assert_approx_eq([1.0000001, 2.0000001], [1.0, 2.0])
	assert_approx_ne([1.0, 2.0], [1.0, 2.00001])
	assert_approx_ne([1.0, 2.0], [1.0])
	assert_approx_ne([1.0], 1.0)
	assert_approx_ne(1.0, [1.0])

	assert_approx_eq([1.0000001, 2.0000001], [1.0, 2.0] as Array[float])
	assert_approx_eq(PackedFloat32Array([1.0, 2.0]), [1.0000001, 2.0000001])
	assert_approx_eq([1.0000001, 2.0000001], PackedFloat32Array([1.0, 2.0]))
	assert_approx_eq([], PackedFloat32Array())
	assert_approx_ne(PackedFloat32Array([1.0]), 1.0)
	assert_approx_ne(1.0, PackedFloat32Array([1.0]))


func test_assert_approx_nested_arrays() -> void:
	assert_approx_eq([[1.0000001], [Vector3.ONE]], [[1.0], [Vector3.ONE]])
	assert_approx_eq([[1.0000001], [Vector3.ONE]], [[1.0], PackedVector3Array([Vector3.ONE])])
	assert_approx_ne([[1.0], [2.0]], [[1.0], [2.00001]])


func test_expect() -> void:
	expect_error("expected error")
	push_error("An expected error occurred.")

	expect_warning("expected warning")
	push_warning("An expected warning occurred.")

	expect_error("expected error")
	expect_error("expected error")
	push_error("An expected error 1 occurred.")
	push_error("An expected error 2 occurred.")

	expect_error("First error")
	expect_warning("First warning")
	push_error("First error")
	push_warning("First warning")
