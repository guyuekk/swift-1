// RUN: %target-run-simple-swift
// REQUIRES: executable_test

// REQUIRES: objc_interop
// UNSUPPORTED: OS=watchos

import StdlibUnittest
import Accelerate

var AccelerateTests = TestSuite("Accelerate")

if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 4.0, *) {
    
    AccelerateTests.test("BNNS/ImageStackDescriptor") {
        var succeed = BNNSImageStackDescriptor(width: 0, height: 0, channels: 0,
                                               row_stride: 0, image_stride: 0,
                                               data_type: .int8)
        expectEqual(succeed.data_scale, 1)
        expectEqual(succeed.data_bias, 0)
        succeed = BNNSImageStackDescriptor(width: 0, height: 0, channels: 0,
                                           row_stride: 0, image_stride: 0,
                                           data_type: .int16,
                                           data_scale: 0.5, data_bias: 0.5)
        expectEqual(succeed.data_scale, 0.5)
        expectEqual(succeed.data_bias, 0.5)
        expectCrashLater()
        //  indexed8 is not allowed as an imageStack data type.
        let _ = BNNSImageStackDescriptor(width: 0, height: 0, channels: 0,
                                         row_stride: 0, image_stride: 0,
                                         data_type: .indexed8)
    }
    
    AccelerateTests.test("BNNS/VectorDescriptor") {
        var succeed = BNNSVectorDescriptor(size: 0, data_type: .int8)
        expectEqual(succeed.data_scale, 1)
        expectEqual(succeed.data_bias, 0)
        succeed = BNNSVectorDescriptor(size: 0, data_type: .int8,
                                       data_scale: 0.5, data_bias: 0.5)
        expectEqual(succeed.data_scale, 0.5)
        expectEqual(succeed.data_bias, 0.5)
        expectCrashLater()
        //  indexed8 is not allowed as a vector data type.
        let _ = BNNSVectorDescriptor(size: 0, data_type: .indexed8)
    }
    
    AccelerateTests.test("BNNS/LayerData") {
        //  The zero layer should have data == nil.
        expectEqual(BNNSLayerData.zero.data, nil)
        var succeed = BNNSLayerData(data: nil, data_type: .int8)
        expectEqual(succeed.data_scale, 1)
        expectEqual(succeed.data_bias, 0)
        succeed = BNNSLayerData(data: nil, data_type: .int8, data_scale: 0.5,
                                data_bias: 0.5, data_table: nil)
        expectEqual(succeed.data_scale, 0.5)
        expectEqual(succeed.data_bias, 0.5)
        var table: [Float] = [1.0]
        succeed = BNNSLayerData.indexed8(data: nil, data_table: &table)
        expectCrashLater()
        // indexed8 requires a non-nil data table.
        let _ = BNNSLayerData(data: nil, data_type: .indexed8)
    }
    
    AccelerateTests.test("BNNS/Activation") {
        expectEqual(BNNSActivation.identity.function, .identity)
        let id = BNNSActivation(function: .identity)
        expectTrue(id.alpha.isNaN)
        expectTrue(id.beta.isNaN)
    }
}

//===----------------------------------------------------------------------===//
//
//  Sliding window summation
//
//===----------------------------------------------------------------------===//

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    
    AccelerateTests.test("vDSP/SinglePrecisionSlidingWindowSum") {
        let source: [Float] = [1, 10, 12, 9, 3, 7, 2, 6]
        var destination = [Float](repeating: .nan, count: 6)
        
        vDSP.slidingWindowSum(source,
                              usingWindowLength: 3,
                              result: &destination)
        
        let returnedResult = vDSP.slidingWindowSum(source,
                                                   usingWindowLength: 3)
        
        expectTrue(destination.elementsEqual(returnedResult))
        expectTrue(destination.map{ Int($0) }.elementsEqual([23, 31, 24, 19, 12, 15]))
    }
    
    AccelerateTests.test("vDSP/DoublePrecisionSlidingWindowSum") {
        let source: [Double] = [1, 10, 12, 9, 3, 7, 2, 6]
        var destination = [Double](repeating: .nan, count: 6)
        
        vDSP.slidingWindowSum(source,
                              usingWindowLength: 3,
                              result: &destination)
        
        let returnedResult = vDSP.slidingWindowSum(source,
                                                   usingWindowLength: 3)
        
        expectTrue(destination.elementsEqual(returnedResult))
        
        expectTrue(destination.map{ Int($0) }.elementsEqual([23, 31, 24, 19, 12, 15]))
    }

}

//===----------------------------------------------------------------------===//
//
//  Linear interpolation
//
//===----------------------------------------------------------------------===//

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    
    let n = 1024
    
    AccelerateTests.test("vDSP/SinglePrecisionInterpolateBetweenVectors") {
        var result = [Float](repeating: 0, count: n)
        var legacyResult = [Float](repeating: -1, count: n)
        
        let a: [Float] = (0 ..< n).map{ i in
            return sin(Float(i) * 0.025)
        }
        
        let b: [Float] =  (0 ..< n).map{ i in
            return sin(Float(i) * 0.05)
        }
        
        let interpolationConstant: Float = 0.5
        
        vDSP.linearInterpolate(a, b,
                               using: interpolationConstant,
                               result: &result)
        
        vDSP_vintb(a, 1,
                   b, 1,
                   [interpolationConstant],
                   &legacyResult, 1,
                   vDSP_Length(n))
        
        let returnedResult = vDSP.linearInterpolate(a, b,
                                                    using: interpolationConstant)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/SinglePrecisionInterpolateBetweenNeighbours") {
        var result = [Float](repeating: 0, count: n)
        var legacyResult = [Float](repeating: -1, count: n)
        
        let shortSignal: [Float] = (0 ... 10).map{ i in
            return sin(Float(i) * 0.1 * .pi * 4)
        }
        
        let controlVector: [Float] = {
            var controlVector = [Float](repeating: 0, count: 1024)
            
            vDSP_vgen([0],
                      [Float(shortSignal.count)],
                      &controlVector, 1,
                      vDSP_Length(n))
            
            return controlVector
        }()
        
        vDSP.linearInterpolate(elementsOf: shortSignal,
                               using: controlVector,
                               result: &result)
        
        vDSP_vlint(shortSignal,
                   controlVector, 1,
                   &legacyResult, 1,
                   vDSP_Length(n),
                   vDSP_Length(shortSignal.count))
        
        let returnedResult = vDSP.linearInterpolate(elementsOf: shortSignal,
                                                    using: controlVector)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/DoublePrecisionInterpolateBetweenVectors") {
        var result = [Double](repeating: 0, count: n)
        var legacyResult = [Double](repeating: -1, count: n)
        
        let a: [Double] = (0 ..< n).map{ i in
            return sin(Double(i) * 0.025)
        }
        
        let b: [Double] =  (0 ..< n).map{ i in
            return sin(Double(i) * 0.05)
        }
        
        let interpolationConstant: Double = 0.5
        
        vDSP.linearInterpolate(a, b,
                               using: interpolationConstant,
                               result: &result)
        
        vDSP_vintbD(a, 1,
                    b, 1,
                    [interpolationConstant],
                    &legacyResult, 1,
                    vDSP_Length(n))
        
        let returnedResult = vDSP.linearInterpolate(a, b,
                                                    using: interpolationConstant)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/DoublePrecisionInterpolateBetweenNeighbours") {
        var result = [Double](repeating: 0, count: n)
        var legacyResult = [Double](repeating: -1, count: n)
        
        let shortSignal: [Double] = (0 ... 10).map{ i in
            return sin(Double(i) * 0.1 * .pi * 4)
        }
        
        let controlVector: [Double] = {
            var controlVector = [Double](repeating: 0, count: 1024)
            
            vDSP_vgenD([0],
                       [Double(shortSignal.count)],
                       &controlVector, 1,
                       vDSP_Length(n))
            
            return controlVector
        }()
        
        vDSP.linearInterpolate(elementsOf: shortSignal,
                               using: controlVector,
                               result: &result)
        
        vDSP_vlintD(shortSignal,
                    controlVector, 1,
                    &legacyResult, 1,
                    vDSP_Length(n),
                    vDSP_Length(shortSignal.count))
        
        let returnedResult = vDSP.linearInterpolate(elementsOf: shortSignal,
                                                    using: controlVector)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
}

//===----------------------------------------------------------------------===//
//
//  vDSP difference equation
//
//===----------------------------------------------------------------------===//

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    
    AccelerateTests.test("vDSP/DifferenceEquationSinglePrecision") {
        let n = 256
        
        let source: [Float] = (0 ..< n).map {
            return sin(Float($0) * 0.05).sign == .minus ? -1 : 1
        }
        var result = [Float](repeating: 0, count: n)
        var legacyResult = [Float](repeating: -1, count: n)
        
        let coefficients: [Float] = [0.0, 0.1, 0.2, 0.4, 0.8]
        
        vDSP.twoPoleTwoZeroFilter(source,
                                  coefficients: (coefficients[0],
                                                 coefficients[1],
                                                 coefficients[2],
                                                 coefficients[3],
                                                 coefficients[4]),
                                  result: &result)
        
        legacyResult[0] = 0
        legacyResult[1] = 0
        
        vDSP_deq22(source, 1,
                   coefficients,
                   &legacyResult, 1,
                   vDSP_Length(n-2))
        
        let returnedResult = vDSP.twoPoleTwoZeroFilter(source,
                                                       coefficients: (coefficients[0],
                                                                      coefficients[1],
                                                                      coefficients[2],
                                                                      coefficients[3],
                                                                      coefficients[4]))
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/DifferenceEquationDoublePrecision") {
        let n = 256
        
        let source: [Double] = (0 ..< n).map {
            return sin(Double($0) * 0.05).sign == .minus ? -1 : 1
        }
        var result = [Double](repeating: 0, count: n)
        var legacyResult = [Double](repeating: -1, count: n)
        
        let coefficients: [Double] = [0.0, 0.1, 0.2, 0.4, 0.8]
        
        vDSP.twoPoleTwoZeroFilter(source,
                                  coefficients: (coefficients[0],
                                                 coefficients[1],
                                                 coefficients[2],
                                                 coefficients[3],
                                                 coefficients[4]),
                                  result: &result)
        
        legacyResult[0] = 0
        legacyResult[1] = 0
        
        vDSP_deq22D(source, 1,
                    coefficients,
                    &legacyResult, 1,
                    vDSP_Length(n-2))
        
        let returnedResult = vDSP.twoPoleTwoZeroFilter(source,
                                                       coefficients: (coefficients[0],
                                                                      coefficients[1],
                                                                      coefficients[2],
                                                                      coefficients[3],
                                                                      coefficients[4]))
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
}

//===----------------------------------------------------------------------===//
//
//  vDSP downsampling
//
//===----------------------------------------------------------------------===//

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    AccelerateTests.test("vDSP/DownsampleSinglePrecision") {
        let decimationFactor = 2
        let filterLength: vDSP_Length = 2
        let filter = [Float](repeating: 1 / Float(filterLength),
                             count: Int(filterLength))
        
        let originalSignal: [Float] = [10, 15, 20, 25, 50, 25, 20, 15, 10,
                                       10, 15, 20, 25, 50, 25, 20, 15, 10]
        
        let inputLength = vDSP_Length(originalSignal.count)
        
        let n = vDSP_Length((inputLength - filterLength) / vDSP_Length(decimationFactor)) + 1
        
        var result = [Float](repeating: 0,
                             count: Int(n))
        
        
        vDSP.downsample(originalSignal,
                        decimationFactor: decimationFactor,
                        filter: filter,
                        result: &result)
        
        var legacyResult = [Float](repeating: -1,
                                   count: Int(n))
        
        vDSP_desamp(originalSignal,
                    decimationFactor,
                    filter,
                    &legacyResult,
                    n,
                    filterLength)
        
        let returnedResult = vDSP.downsample(originalSignal,
                                             decimationFactor: decimationFactor,
                                             filter: filter)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/DownsampleDoublePrecision") {
        let decimationFactor = 2
        let filterLength: vDSP_Length = 2
        let filter = [Double](repeating: 1 / Double(filterLength),
                              count: Int(filterLength))
        
        let originalSignal: [Double] = [10, 15, 20, 25, 50, 25, 20, 15, 10,
                                        10, 15, 20, 25, 50, 25, 20, 15, 10]
        
        let inputLength = vDSP_Length(originalSignal.count)
        
        let n = vDSP_Length((inputLength - filterLength) / vDSP_Length(decimationFactor)) + 1
        
        var result = [Double](repeating: 0,
                              count: Int(n))
        
        
        vDSP.downsample(originalSignal,
                        decimationFactor: decimationFactor,
                        filter: filter,
                        result: &result)
        
        var legacyResult = [Double](repeating: -1,
                                    count: Int(n))
        
        vDSP_desampD(originalSignal,
                     decimationFactor,
                     filter,
                     &legacyResult,
                     n,
                     filterLength)
        
        let returnedResult = vDSP.downsample(originalSignal,
                                             decimationFactor: decimationFactor,
                                             filter: filter)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
}

//===----------------------------------------------------------------------===//
//
//  vDSP polynomial evaluation.
//
//===----------------------------------------------------------------------===//

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    
    AccelerateTests.test("vDSP/PolynomialEvaluationSinglePrecision") {
        let coefficients: [Float] = [2, 3, 4, 5, 6, 7, 8, 9, 10]
        let variables = (0 ... 100).map { return Float($0) }
        var result = [Float](repeating: 0, count: variables.count)
        
        vDSP.evaluatePolynomial(usingCoefficients: coefficients,
                                withVariables: variables,
                                result: &result)
        
        var legacyResult = [Float](repeating: -1, count: variables.count)
        
        vDSP_vpoly(coefficients, 1,
                   variables, 1,
                   &legacyResult, 1,
                   vDSP_Length(legacyResult.count),
                   vDSP_Length(coefficients.count - 1))
        
        let returnedResult = vDSP.evaluatePolynomial(usingCoefficients: coefficients,
                                                     withVariables: variables)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
    
    AccelerateTests.test("vDSP/PolynomialEvaluationDoublePrecision") {
        let coefficients: [Double] = [2, 3, 4, 5, 6, 7, 8, 9, 10]
        let variables = (0 ... 100).map { return Double($0) }
        var result = [Double](repeating: 0, count: variables.count)
        
        vDSP.evaluatePolynomial(usingCoefficients: coefficients,
                                withVariables: variables,
                                result: &result)
        
        var legacyResult = [Double](repeating: -1, count: variables.count)
        
        vDSP_vpolyD(coefficients, 1,
                    variables, 1,
                    &legacyResult, 1,
                    vDSP_Length(legacyResult.count),
                    vDSP_Length(coefficients.count - 1))
        
        let returnedResult = vDSP.evaluatePolynomial(usingCoefficients: coefficients,
                                                     withVariables: variables)
        
        expectTrue(result.elementsEqual(legacyResult))
        expectTrue(result.elementsEqual(returnedResult))
    }
}

runAllTests()

