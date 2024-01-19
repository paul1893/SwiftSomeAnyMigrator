import XCTest
import SwiftParser
@testable import SwiftSomeAnyMigrator

final class SwiftSomeAnyMigratorTests: XCTestCase {
    
    override func setUp() {
        Metadata.policy = .strict
        Metadata.conservative = false
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
        let rewriter = GlobalVariableProtocolRewriter()
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
        let rewriter = GlobalVariableProtocolRewriter()
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
        let rewriter = GlobalVariableProtocolRewriter()
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

    func test_constructor_rewriter() throws {
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
        let rewriter = InitializerProtocolRewriter()
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

    func test_constructor_rewriter_with_excluded_named() throws {
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
        let rewriter = InitializerProtocolRewriter()
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

    func test_constructor_rewriter_when_conservative() throws {
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
        let rewriter = InitializerProtocolRewriter()
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

    func test_constructor_rewriter_replace_any_by_some_if_strict_policy() throws {
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
        let rewriter = InitializerProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
        let rewriter = FunctionProtocolRewriter()
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
}
