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
