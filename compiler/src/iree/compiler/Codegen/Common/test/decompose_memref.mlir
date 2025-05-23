// RUN: iree-opt --split-input-file --pass-pipeline="builtin.module(func.func(iree-codegen-decompose-memrefs))" %s | FileCheck %s

func.func @load_scalar_from_memref(%input: memref<4x8xf32, strided<[8, 1], offset: 100>>) -> f32 {
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %value = memref.load %input[%c1, %c2] : memref<4x8xf32, strided<[8, 1], offset: 100>>
  return %value : f32
}
// CHECK: func @load_scalar_from_memref
// CHECK: %[[C10:.*]] = arith.constant 10 : index
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %arg0 to offset: [100], sizes: [32], strides: [1]
// CHECK-SAME: memref<4x8xf32, strided<[8, 1], offset: 100>> to memref<32xf32, strided<[1], offset: 100>>
// CHECK: memref.load %[[REINT]][%[[C10]]] : memref<32xf32, strided<[1], offset: 100>>

// -----

func.func @load_scalar_from_memref_static_dim_2(%input: memref<4x8xf32, strided<[8, 12], offset: 100>>, %row: index, %col: index) -> f32 {
  %value = memref.load %input[%col, %row] : memref<4x8xf32, strided<[8, 12], offset: 100>>
  return %value : f32
}
// CHECK: [[MAP:.+]] = affine_map<()[s0, s1] -> (s0 * 8 + s1 * 12)>
// CHECK: func @load_scalar_from_memref_static_dim_2
// CHECK-SAME: (%[[ARG0:.*]]: memref<4x8xf32, strided<[8, 12], offset: 100>>, %[[ARG1:.*]]: index, %[[ARG2:.*]]: index)
// CHECK: %[[IDX:.*]] = affine.apply [[MAP]]()[%[[ARG2]], %[[ARG1]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]] to offset: [100], sizes: [32], strides: [12]
// CHECK-SAME: to memref<32xf32, strided<[12], offset: 100>>
// CHECK: memref.load %[[REINT]][%[[IDX]]]

// -----

func.func @load_scalar_from_memref_dynamic_dim(%input: memref<?x?xf32, strided<[?, ?], offset: ?>>, %row: index, %col: index) -> f32 {
  %value = memref.load %input[%col, %row] : memref<?x?xf32, strided<[?, ?], offset: ?>>
  return %value : f32
}

// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1, s2, s3] -> (s0 * s1 + s2 * s3)>
// CHECK: #[[MAP1:.*]] = affine_map<()[s0, s1] -> (s0 * s1)>
// CHECK: func @load_scalar_from_memref_dynamic_dim
// CHECK-SAME: (%[[ARG0:.*]]: memref<?x?xf32, strided<[?, ?], offset: ?>>, %[[ARG1:.*]]: index, %[[ARG2:.*]]: index)
// CHECK: %[[BASE:.*]], %[[OFFSET:.*]], %[[SIZES:.*]]:2, %[[STRIDES:.*]]:2 = memref.extract_strided_metadata %[[ARG0]]
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG2]], %[[STRIDES]]#0, %[[ARG1]], %[[STRIDES]]#1]
// CHECK: %[[SIZE:.*]] = affine.apply #[[MAP1]]()[%[[STRIDES]]#0, %[[SIZES]]#0]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]] to offset: [%[[OFFSET]]], sizes: [%[[SIZE]]], strides: [%[[STRIDES]]#1]
// CHECK: memref.load %[[REINT]][%[[IDX]]]

// -----

func.func @load_scalar_from_memref_subview(%input: memref<4x8xf32>, %row: index, %col: index) -> memref<1x1xf32, strided<[8, 1], offset: ?>> {
  %subview = memref.subview %input[%col, %row] [1, 1] [1, 1] : memref<4x8xf32> to memref<1x1xf32, strided<[8, 1], offset: ?>>
  return %subview : memref<1x1xf32, strided<[8, 1], offset: ?>>
}
// CHECK: func @load_scalar_from_memref_subview

// -----

func.func @store_scalar_from_memref_static_dim(%input: memref<4x8xf32, strided<[8, 12], offset: 100>>, %row: index, %col: index, %value: f32) {
  memref.store %value, %input[%col, %row] : memref<4x8xf32, strided<[8, 12], offset: 100>>
  return
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1] -> (s0 * 8 + s1 * 12)>
// CHECK: func @store_scalar_from_memref_static_dim
// CHECK-SAME: (%[[ARG0:.*]]: memref<4x8xf32, strided<[8, 12], offset: 100>>, %[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: f32)
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG2]], %[[ARG1]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]]
// CHECK: memref.store %[[ARG3]], %[[REINT]][%[[IDX]]] : memref<32xf32, strided<[12], offset: 100>>

// -----

func.func @store_scalar_from_memref_dynamic_dim(%input: memref<?x?xf32, strided<[?, ?], offset: ?>>, %row: index, %col: index, %value: f32) {
  memref.store %value, %input[%col, %row] : memref<?x?xf32, strided<[?, ?], offset: ?>>
  return
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1, s2, s3] -> (s0 * s1 + s2 * s3)>
// CHECK: #[[MAP1:.*]] = affine_map<()[s0, s1] -> (s0 * s1)>
// CHECK: func @store_scalar_from_memref_dynamic_dim
// CHECK-SAME: (%[[ARG0:.*]]: memref<?x?xf32, strided<[?, ?], offset: ?>>, %[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: f32)
// CHECK: %[[BASE:.*]], %[[OFFSET:.*]], %[[SIZES:.*]]:2, %[[STRIDES:.*]]:2 = memref.extract_strided_metadata %[[ARG0]]
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG2]], %[[STRIDES]]#0, %[[ARG1]], %[[STRIDES]]#1]
// CHECK: %[[SIZE:.*]] = affine.apply #[[MAP1]]()[%[[STRIDES]]#0, %[[SIZES]]#0]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]] to offset: [%[[OFFSET]]], sizes: [%[[SIZE]]], strides: [%[[STRIDES]]#1]
// CHECK: memref.store %[[ARG3]], %[[REINT]][%[[IDX]]]

// -----

func.func @load_vector_from_memref(%input: memref<4x8xf32>) -> vector<8xf32> {
  %c3 = arith.constant 3 : index
  %c6 = arith.constant 6 : index
  %value = vector.load %input[%c3, %c6] : memref<4x8xf32>, vector<8xf32>
  return %value : vector<8xf32>
}
// CHECK: func @load_vector_from_memref
// CHECK: %[[C30:.*]] = arith.constant 30
// CHECK-NEXT: %[[REINT:.*]] = memref.reinterpret_cast %arg0 to offset: [0], sizes: [32], strides: [1]
// CHECK-NEXT: vector.load %[[REINT]][%[[C30]]]

// -----

func.func @load_vector_from_memref_odd(%input: memref<3x7xi2>) -> vector<3xi2> {
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  %value = vector.load %input[%c1, %c3] : memref<3x7xi2>, vector<3xi2>
  return %value : vector<3xi2>
}
// CHECK: func @load_vector_from_memref_odd
// CHECK: %[[C10:.*]] = arith.constant 10 : index
// CHECK-NEXT: %[[REINT:.*]] = memref.reinterpret_cast
// CHECK-NEXT: vector.load %[[REINT]][%[[C10]]]

// -----

func.func @load_vector_from_memref_dynamic(%input: memref<3x7xi2>, %row: index, %col: index) -> vector<3xi2> {
  %value = vector.load %input[%col, %row] : memref<3x7xi2>, vector<3xi2>
  return %value : vector<3xi2>
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1] -> (s0 * 7 + s1)>
// CHECK: func @load_vector_from_memref_dynamic
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast
// CHECK: vector.load %[[REINT]][%[[IDX]]] : memref<21xi2, strided<[1]>>, vector<3xi2>

// -----

func.func @store_vector_to_memref_odd(%input: memref<3x7xi2>, %value: vector<3xi2>) {
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  vector.store %value, %input[%c1, %c3] : memref<3x7xi2>, vector<3xi2>
  return
}
// CHECK: func @store_vector_to_memref_odd
// CHECK: %[[C10:.*]] = arith.constant 10 : index
// CHECK-NEXT: %[[REINT:.*]] = memref.reinterpret_cast
// CHECK-NEXT: vector.store %arg1, %[[REINT]][%[[C10]]] : memref<21xi2, strided<[1]>

// -----

func.func @store_vector_to_memref_dynamic(%input: memref<3x7xi2>, %value: vector<3xi2>, %row: index, %col: index) {
  vector.store %value, %input[%col, %row] : memref<3x7xi2>, vector<3xi2>
  return
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1] -> (s0 * 7 + s1)>
// CHECK: func @store_vector_to_memref_dynamic
// CHECK-SAME: (%[[ARG0:.*]]: memref<3x7xi2>, %[[ARG1:.*]]: vector<3xi2>, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index)
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG3]], %[[ARG2]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]] to offset: [0], sizes: [21], strides: [1]
// CHECK: vector.store %[[ARG1]], %[[REINT]][%[[IDX]]]

// -----

func.func @mask_store_vector_to_memref_odd(%input: memref<3x7xi2>, %value: vector<3xi2>, %mask: vector<3xi1>) {
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  vector.maskedstore %input[%c1, %c3], %mask, %value  : memref<3x7xi2>, vector<3xi1>, vector<3xi2>
  return
}
// CHECK: func @mask_store_vector_to_memref_odd
// CHECK-SAME: (%[[ARG0:.*]]: memref<3x7xi2>, %[[ARG1:.*]]: vector<3xi2>, %[[ARG2:.*]]: vector<3xi1>)
// CHECK: %[[C10:.*]] = arith.constant 10 : index
// CHECK-NEXT: %[[REINT:.*]] = memref.reinterpret_cast
// CHECK: vector.maskedstore %[[REINT]][%[[C10]]], %[[ARG2]], %[[ARG1]]

// -----

func.func @mask_store_vector_to_memref_dynamic(%input: memref<3x7xi2>, %value: vector<3xi2>, %row: index, %col: index, %mask: vector<3xi1>) {
  vector.maskedstore %input[%col, %row], %mask, %value : memref<3x7xi2>, vector<3xi1>, vector<3xi2>
  return
}
// CHECK: #map = affine_map<()[s0, s1] -> (s0 * 7 + s1)>
// CHECK: func @mask_store_vector_to_memref_dynamic
// CHECK-SAME: (%[[ARG0:.*]]: memref<3x7xi2>, %[[ARG1:.*]]: vector<3xi2>, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index, %[[ARG4:.*]]: vector<3xi1>)
// CHECK: %[[IDX:.*]] = affine.apply #map()[%[[ARG3]], %[[ARG2]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]]
// CHECK: vector.maskedstore %[[REINT]][%[[IDX]]], %[[ARG4]], %[[ARG1]]

// -----
func.func @mask_load_vector_from_memref_odd(%input: memref<3x7xi2>, %mask: vector<3xi1>, %passthru: vector<3xi2>) -> vector<3xi2> {
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  %result = vector.maskedload %input[%c1, %c3], %mask, %passthru : memref<3x7xi2>, vector<3xi1>, vector<3xi2> into vector<3xi2>
  return %result : vector<3xi2>
}
// CHECK: func @mask_load_vector_from_memref_odd
// CHECK-SAME: (%[[ARG0:.*]]: memref<3x7xi2>, %[[MASK:.*]]: vector<3xi1>, %[[PASSTHRU:.*]]: vector<3xi2>)
// CHECK: %[[C10:.*]] = arith.constant 10 : index
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]] to offset: [0], sizes: [21], strides: [1]
// CHECK: vector.maskedload %[[REINT]][%[[C10]]], %[[MASK]], %[[PASSTHRU]]

// -----

func.func @mask_load_vector_from_memref_dynamic(%input: memref<3x7xi2>, %row: index, %col: index, %mask: vector<3xi1>, %passthru: vector<3xi2>) -> vector<3xi2> {
  %result = vector.maskedload %input[%col, %row], %mask, %passthru : memref<3x7xi2>, vector<3xi1>, vector<3xi2> into vector<3xi2>
  return %result : vector<3xi2>
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1] -> (s0 * 7 + s1)>
// CHECK: func @mask_load_vector_from_memref_dynamic
// CHECK-SAME: (%[[ARG0:.*]]: memref<3x7xi2>, %[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: vector<3xi1>, %[[ARG4:.*]]: vector<3xi2>)
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG2]], %[[ARG1]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]]
// CHECK: vector.maskedload %[[REINT]][%[[IDX]]], %[[ARG3]]

// -----

func.func @transfer_read_memref(%input: memref<4x8xi2>, %value: vector<8xi2>, %row: index, %col: index) -> vector<8xi2> {
   %c0 = arith.constant 0 : i2
   %0 = vector.transfer_read %input[%col, %row], %c0 : memref<4x8xi2>, vector<8xi2>
   return %0 : vector<8xi2>
}
// CHECK: func @transfer_read_memref
// CHECK-SAME: (%[[ARG0:.*]]: memref<4x8xi2>, %[[ARG1:.*]]: vector<8xi2>, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index)
// CHECK: %[[C0:.*]] = arith.constant 0 : i2
// CHECK: %[[IDX:.*]] = affine.apply #map()[%[[ARG3]], %[[ARG2]]]
// CHECK-NEXT: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]]
// CHECK-NEXT: vector.transfer_read %[[REINT]][%[[IDX]]], %[[C0]]

// -----

func.func @transfer_write_memref(%input: memref<4x8xi2>, %value: vector<8xi2>, %row: index, %col: index) {
   vector.transfer_write %value, %input[%col, %row] : vector<8xi2>, memref<4x8xi2>
   return
}
// CHECK: #[[MAP:.*]] = affine_map<()[s0, s1] -> (s0 * 8 + s1)>
// CHECK: func @transfer_write_memref
// CHECK-SAME: (%[[ARG0:.*]]: memref<4x8xi2>, %[[ARG1:.*]]: vector<8xi2>, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index)
// CHECK: %[[IDX:.*]] = affine.apply #[[MAP]]()[%[[ARG3]], %[[ARG2]]]
// CHECK: %[[REINT:.*]] = memref.reinterpret_cast %[[ARG0]]
// CHECK: vector.transfer_write %[[ARG1]], %[[REINT]][%[[IDX]]]
