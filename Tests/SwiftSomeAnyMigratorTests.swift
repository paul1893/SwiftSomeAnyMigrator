import XCTest
import SwiftParser
import SwiftSyntax
@testable import SwiftSomeAnyMigrator

final class SwiftSomeAnyMigratorTests: XCTestCase {
    
    override func setUp() {
        Metadata.policy = .strict
        Metadata.conservative = false
        Collector.protocols = Set(["FooProtocol", "BarProtocol", "Error"].map {
            TokenSyntax.identifier($0)
        })
    }
    
    func test_variable_rewriter_with_excluded_named() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: AppDelegate
            private var b: SceneDelegate
            private var c: FooProtocolMock
            init() {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: AppDelegate
                private var b: SceneDelegate
                private var c: FooProtocolMock
                init() {}
             }
            """
        )
    }
    
    func test_variable_rewriter_with_default_value_is_a_function() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: any FooProtocol = self.call()
            private var b: (any BarProtocol)? = self.call()
            private var c: FooProtocol = self.call()
            private var d: BarProtocol? = self.call()
            init() {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol = self.call()
                private var b: (any BarProtocol)? = self.call()
                private var c: any FooProtocol = self.call()
                private var d: (any BarProtocol)? = self.call()
                init() {}
             }
            """
        )
    }
    
    func test_variable_rewriter() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: any FooProtocol
            private var b: (any BarProtocol)?
            private var c: FooProtocol
            private var d: BarProtocol?
            init() {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol
                private var b: (any BarProtocol)?
                private var c: any FooProtocol
                private var d: (any BarProtocol)?
                init() {}
             }
            """
        )
    }
    
    func test_variable_closure_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            let closureWithGeneric: (AnyPublisher<FooProtocol, Error>) -> Void
            let closureWithGenericOptional: (AnyPublisher<FooProtocol?, Error>) -> Void
            let closure: (FooProtocol) -> FooProtocol
            let closureOptional: (FooProtocol?) -> FooProtocol?
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                let closureWithGeneric: (AnyPublisher<any FooProtocol, any Error>) -> Void
                let closureWithGenericOptional: (AnyPublisher<(any FooProtocol)?, any Error>) -> Void
                let closure: (any FooProtocol) -> any FooProtocol
                let closureOptional: ((any FooProtocol)?) -> (any FooProtocol)?
             }
            """
        )
    }
    
    func test_variable_closure_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            typealias CustomBar = AnyPublisher<Bar, Error>
            typealias CustomBarOptional = AnyPublisher<Bar?, Error>
            let publisher: AnyPublisher<Bar, Error>
            let publisherOptional: AnyPublisher<Bar?, Error>
            let closureWithGeneric: (AnyPublisher<Bar, Error>) -> Void
            let closureWithGenericOptional: (AnyPublisher<Bar?, Error>) -> Void
            let closure: (Bar) -> Bar
            let closureOptional: (Bar?) -> Bar?
            
            func foo() -> AnyPublisher<Bar, Error> {
                var publisher: AnyPublisher<Bar, Error> = Just(nil).eraseToAnyPublisher()
                var publisherOptional: AnyPublisher<Bar?, Error> = Just(nil).eraseToAnyPublisher()
                var a: Bar = Foo()
                var b: Bar? = Foo()
                let localClosure: (Bar) -> Bar
                let localClosureWithOptionalParameters: (Bar?) -> Bar?
                let localClosureOptionalWithOptionalParameters: ((Bar?) -> Bar?)?
                let localClosureOptional: ((Bar) -> Bar)?
            }
            func bar(_ a: AnyPublisher<Bar, Error>) {}
            var bar: AnyPublisher<Bar, Error> {}
            var barOptional: AnyPublisher<Bar?, Error> {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                typealias CustomBar = AnyPublisher<Bar, any Error>
                typealias CustomBarOptional = AnyPublisher<Bar?, any Error>
                let publisher: AnyPublisher<Bar, any Error>
                let publisherOptional: AnyPublisher<Bar?, any Error>
                let closureWithGeneric: (AnyPublisher<Bar, any Error>) -> Void
                let closureWithGenericOptional: (AnyPublisher<Bar?, any Error>) -> Void
                let closure: (Bar) -> Bar
                let closureOptional: (Bar?) -> Bar?
                
                func foo() -> AnyPublisher<Bar, any Error> {
                    var publisher: AnyPublisher<Bar, any Error> = Just(nil).eraseToAnyPublisher()
                    var publisherOptional: AnyPublisher<Bar?, any Error> = Just(nil).eraseToAnyPublisher()
                    var a: Bar = Foo()
                    var b: Bar? = Foo()
                    let localClosure: (Bar) -> Bar
                    let localClosureWithOptionalParameters: (Bar?) -> Bar?
                    let localClosureOptionalWithOptionalParameters: ((Bar?) -> Bar?)?
                    let localClosureOptional: ((Bar) -> Bar)?
                }
                func bar(_ a: AnyPublisher<Bar, any Error>) {}
                var bar: AnyPublisher<Bar, any Error> {}
                var barOptional: AnyPublisher<Bar?, any Error> {}
             }
            """
        )
    }
    
    func test_variable_generic_type_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            let publisher: AnyPublisher<FooProtocol, Error>
            let publisherOptional: AnyPublisher<FooProtocol?, Error>
            var bar: AnyPublisher<FooProtocol, Error> {}
            var barOptional: AnyPublisher<FooProtocol?, Error> {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                let publisher: AnyPublisher<any FooProtocol, any Error>
                let publisherOptional: AnyPublisher<(any FooProtocol)?, any Error>
                var bar: AnyPublisher<any FooProtocol, any Error> {}
                var barOptional: AnyPublisher<(any FooProtocol)?, any Error> {}
             }
            """
        )
    }
    
    func test_variable_generic_type_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            let publisher: AnyPublisher<Bar, Error>
            let publisherOptional: AnyPublisher<Bar?, Error>
            var bar: AnyPublisher<Bar, Error> {}
            var barOptional: AnyPublisher<Bar?, Error> {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                let publisher: AnyPublisher<Bar, any Error>
                let publisherOptional: AnyPublisher<Bar?, any Error>
                var bar: AnyPublisher<Bar, any Error> {}
                var barOptional: AnyPublisher<Bar?, any Error> {}
             }
            """
        )
    }
    
    func test_computed_variable_rewriter() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: FooProtocol { Foo() }
            private var b: FooProtocol? { nil }
            private var body: some View { nil }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol { Foo() }
                private var b: (any FooProtocol)? { nil }
                private var body: some View { nil }
             }
            """
        )
    }
    
    func test_initializer_rewriter() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: any FooProtocol
            private var b: any FooProtocol
            private var c: any FooProtocol
            private var d: (any BarProtocol)?
            private var e: (any BarProtocol)?
        
            init(
                a: FooProtocol,
                b: FooProtocol = Services.shared.foo,
                c: FooProtocol = Foo(),
                d: BarProtocol?,
                e: BarProtocol? = Services.shared.bar
            ) {
                self.a = a
                self.b = b
                self.c = c
                self.d = d
                self.e = e
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol
                private var b: any FooProtocol
                private var c: any FooProtocol
                private var d: (any BarProtocol)?
                private var e: (any BarProtocol)?
            
                init(
                    a: some FooProtocol,
                    b: any FooProtocol = Services.shared.foo,
                    c: some FooProtocol = Foo(),
                    d: (any BarProtocol)?,
                    e: (any BarProtocol)? = Services.shared.bar
                ) {
                    self.a = a
                    self.b = b
                    self.c = c
                    self.d = d
                    self.e = e
                }
             }
            """
        )
    }
    
    func test_initializer_rewriter_with_excluded_named() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: AppDelegate
            private var b: SceneDelegate
            private var c: FooProtocolMock
        
            init(
                a: AppDelegate,
                b: SceneDelegate,
                c: FooProtocolMock
            ) {
                self.a = a
                self.b = b
                self.c = c
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: AppDelegate
                private var b: SceneDelegate
                private var c: FooProtocolMock
            
                init(
                    a: AppDelegate,
                    b: SceneDelegate,
                    c: FooProtocolMock
                ) {
                    self.a = a
                    self.b = b
                    self.c = c
                }
             }
            """
        )
    }
    
    func test_initializer_rewriter_when_conservative() throws {
        // GIVEN
        Metadata.conservative = true
        let source = """
         final class MyClass {
            private var a: any FooProtocol
            private var b: any FooProtocol
            private var c: any FooProtocol
            private var d: (any BarProtocol)?
            private var e: (any BarProtocol)?
        
            init(
                a: any FooProtocol,
                b: any FooProtocol = Services.shared.foo,
                c: any FooProtocol = Foo(),
                d: any BarProtocol?,
                e: any BarProtocol? = Services.shared.bar
            ) {
                self.a = a
                self.b = b
                self.c = c
                self.d = d
                self.e = e
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol
                private var b: any FooProtocol
                private var c: any FooProtocol
                private var d: (any BarProtocol)?
                private var e: (any BarProtocol)?
            
                init(
                    a: any FooProtocol,
                    b: any FooProtocol = Services.shared.foo,
                    c: any FooProtocol = Foo(),
                    d: any BarProtocol?,
                    e: any BarProtocol? = Services.shared.bar
                ) {
                    self.a = a
                    self.b = b
                    self.c = c
                    self.d = d
                    self.e = e
                }
             }
            """
        )
    }
    
    func test_initializer_rewriter_replace_any_by_some_if_strict_policy() throws {
        // GIVEN
        let source = """
         final class MyClass {
            private var a: any FooProtocol
            private var b: any FooProtocol
            private var c: any FooProtocol
            private var d: (any BarProtocol)?
            private var e: (any BarProtocol)?
            private var f: (any BarProtocol)?
        
            init(
                a: any FooProtocol,
                b: any FooProtocol = Services.shared.foo,
                c: any FooProtocol = Foo(),
                d: (any BarProtocol)?,
                e: (any BarProtocol)? = Services.shared.bar,
                f: (any BarProtocol)? = nil
            ) {
                self.a = a
                self.b = b
                self.c = c
                self.d = d
                self.e = e
                self.f = f
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                private var a: any FooProtocol
                private var b: any FooProtocol
                private var c: any FooProtocol
                private var d: (any BarProtocol)?
                private var e: (any BarProtocol)?
                private var f: (any BarProtocol)?
            
                init(
                    a: some FooProtocol,
                    b: any FooProtocol = Services.shared.foo,
                    c: some FooProtocol = Foo(),
                    d: (any BarProtocol)?,
                    e: (any BarProtocol)? = Services.shared.bar,
                    f: (any BarProtocol)? = nil
                ) {
                    self.a = a
                    self.b = b
                    self.c = c
                    self.d = d
                    self.e = e
                    self.f = f
                }
             }
            """
        )
    }
    
    func test_function_rewriter() throws {
        // GIVEN
        let source = """
         final class MyClass {
            func name(
                a: FooProtocol,
                b: BarProtocol?,
                c: BarProtocol? = Services.shared.bar
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: some FooProtocol,
                    b: (any BarProtocol)?,
                    c: (any BarProtocol)? = Services.shared.bar
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_with_excluded_name() throws {
        // GIVEN
        let source = """
         final class MyClass {
            func name(
                a: AppDelegate,
                b: SceneDelegate,
                c: FooProtocolMock
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: AppDelegate,
                    b: SceneDelegate,
                    c: FooProtocolMock
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_when_conservative() throws {
        // GIVEN
        Metadata.conservative = true
        let source = """
         final class MyClass {
            func name(
                a: any FooProtocol,
                b: any BarProtocol?,
                c: any BarProtocol? = Services.shared.bar
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: any FooProtocol,
                    b: any BarProtocol?,
                    c: any BarProtocol? = Services.shared.bar
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_when_policy_light() throws {
        // GIVEN
        Metadata.policy = .light
        let source = """
         final class MyClass {
            func name(
                a: FooProtocol,
                b: BarProtocol?,
                c: BarProtocol? = Services.shared.bar
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: any FooProtocol,
                    b: (any BarProtocol)?,
                    c: (any BarProtocol)? = Services.shared.bar
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_replace_any_by_some_if_strict_policy() throws {
        // GIVEN
        let source = """
         final class MyClass {
            func name(
                a: any FooProtocol,
                b: (any BarProtocol)?,
                c: (any BarProtocol)? = Services.shared.bar
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: some FooProtocol,
                    b: (any BarProtocol)?,
                    c: (any BarProtocol)? = Services.shared.bar
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_optimization_some_any_when_nil() throws {
        // GIVEN
        let source = """
         final class MyClass {
            func name(
                a: FooProtocol,
                b: BarProtocol?,
                c: BarProtocol? = Services.shared.bar
            ) {
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class MyClass {
                func name(
                    a: some FooProtocol,
                    b: (any BarProtocol)?,
                    c: (any BarProtocol)? = Services.shared.bar
                ) {
                }
             }
            """
        )
    }
    
    func test_function_rewriter_with_return_type() throws {
        // GIVEN
        let source = """
         final class FooClass {
            func foo() -> FooProtocol {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                func foo() -> some FooProtocol {}
             }
            """
        )
    }
    
    func test_function_rewriter_with_return_optional_type() throws {
        // GIVEN
        let source = """
         final class FooClass {
            func foo() -> FooProtocol? {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                func foo() -> (any FooProtocol)? {}
             }
            """
        )
    }
    
    func test_function_body_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            func foo() -> AnyPublisher<FooProtocol, Error> {
                var publisher: AnyPublisher<FooProtocol, Error> = Just(nil).eraseToAnyPublisher()
                var publisherOptional: AnyPublisher<FooProtocol?, Error> = Just(nil).eraseToAnyPublisher()
                var a: FooProtocol = Foo()
                var b: FooProtocol? = Foo()
                let localClosure: (FooProtocol) -> FooProtocol
                let localClosureWithOptionalParameters: (FooProtocol?) -> FooProtocol?
                let localClosureOptionalWithOptionalParameters: ((FooProtocol?) -> FooProtocol?)?
                let localClosureOptional: ((FooProtocol) -> FooProtocol)?
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                func foo() -> AnyPublisher<any FooProtocol, any Error> {
                    var publisher: AnyPublisher<any FooProtocol, any Error> = Just(nil).eraseToAnyPublisher()
                    var publisherOptional: AnyPublisher<(any FooProtocol)?, any Error> = Just(nil).eraseToAnyPublisher()
                    var a: any FooProtocol = Foo()
                    var b: (any FooProtocol)? = Foo()
                    let localClosure: (any FooProtocol) -> any FooProtocol
                    let localClosureWithOptionalParameters: ((any FooProtocol)?) -> (any FooProtocol)?
                    let localClosureOptionalWithOptionalParameters: (((any FooProtocol)?) -> (any FooProtocol)?)?
                    let localClosureOptional: ((any FooProtocol) -> any FooProtocol)?
                }
             }
            """
        )
    }
    
    func test_function_body_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            func foo() -> AnyPublisher<Bar, Error> {
                var publisher: AnyPublisher<Bar, Error> = Just(nil).eraseToAnyPublisher()
                var publisherOptional: AnyPublisher<Bar?, Error> = Just(nil).eraseToAnyPublisher()
                var a: Bar = Foo()
                var b: Bar? = Foo()
                let localClosure: (Bar) -> Bar
                let localClosureWithOptionalParameters: (Bar?) -> Bar?
                let localClosureOptionalWithOptionalParameters: ((Bar?) -> Bar?)?
                let localClosureOptional: ((Bar) -> Bar)?
            }
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                func foo() -> AnyPublisher<Bar, any Error> {
                    var publisher: AnyPublisher<Bar, any Error> = Just(nil).eraseToAnyPublisher()
                    var publisherOptional: AnyPublisher<Bar?, any Error> = Just(nil).eraseToAnyPublisher()
                    var a: Bar = Foo()
                    var b: Bar? = Foo()
                    let localClosure: (Bar) -> Bar
                    let localClosureWithOptionalParameters: (Bar?) -> Bar?
                    let localClosureOptionalWithOptionalParameters: ((Bar?) -> Bar?)?
                    let localClosureOptional: ((Bar) -> Bar)?
                }
             }
            """
        )
    }
    
    func test_function_parameters_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            func bar(_ a: AnyPublisher<FooProtocol, Error>) {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                func bar(_ a: AnyPublisher<any FooProtocol, any Error>) {}
             }
            """
        )
    }
    
    func test_function_parameters_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            func bar(_ a: AnyPublisher<Bar, Error>) {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                func bar(_ a: AnyPublisher<Bar, any Error>) {}
             }
            """
        )
    }
    
    func test_function_returnClause_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            func bar() -> AnyPublisher<FooProtocol, Error> {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                func bar() -> AnyPublisher<any FooProtocol, any Error> {}
             }
            """
        )
    }
    
    func test_function_returnClause_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            func bar() -> AnyPublisher<Bar, Error> {}
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                func bar() -> AnyPublisher<Bar, any Error> {}
             }
            """
        )
    }
    
    func test_typealias_rewriter() throws {
        // GIVEN
        let source = """
         final class FooClass {
            typealias CustomFoo = AnyPublisher<FooProtocol, Error>
            typealias CustomFooOptional = AnyPublisher<FooProtocol?, Error>
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class FooClass {
                typealias CustomFoo = AnyPublisher<any FooProtocol, any Error>
                typealias CustomFooOptional = AnyPublisher<(any FooProtocol)?, any Error>
             }
            """
        )
    }
    
    func test_typealias_rewriter_should_not_touch_non_protocol() throws {
        // GIVEN
        let source = """
         final class BarClass {
            typealias CustomBar = AnyPublisher<Bar, Error>
            typealias CustomBarOptional = AnyPublisher<Bar?, Error>
         }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
             final class BarClass {
                typealias CustomBar = AnyPublisher<Bar, any Error>
                typealias CustomBarOptional = AnyPublisher<Bar?, any Error>
             }
            """
        )
    }
    
    func test_should_not_touch_computed_var_of_SwiftUI_views() throws {
        // GIVEN
        let source = """
        @main
        struct SampleApp: App {
            var body: some Scene {
                WindowGroup {
                    Text("")
                }
            }
        }
        """
        
        // WHEN
        let rewriter = MyRewriter()
        let result = rewriter.visit(Parser.parse(source: source))
        
        // THEN
        XCTAssertEqual(
            result.description,
            """
            @main
            struct SampleApp: App {
                var body: some Scene {
                    WindowGroup {
                        Text("")
                    }
                }
            }
            """
        )
    }
    
}
