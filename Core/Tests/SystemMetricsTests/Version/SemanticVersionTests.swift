import Testing
@testable import SystemMetrics

@Suite("SemanticVersion")
struct SemanticVersionTests {

    private func v(_ s: String) throws -> SemanticVersion {
        try #require(SemanticVersion(s))
    }

    /// The bug this type exists to prevent. Compared as strings, "0.10.0" is
    /// *older* than "0.9.2", so the tenth release would never offer an update.
    @Test func tenIsNewerThanNine() throws {
        #expect(try v("0.9.2") < v("0.10.0"))
        #expect(try v("1.9.0") < v("1.10.0"))
    }

    @Test func ordersNormally() throws {
        #expect(try v("0.1.0") < v("0.2.0"))
        #expect(try v("0.1.0") < v("1.0.0"))
        #expect(try v("1.0.1") < v("1.1.0"))
    }

    /// Release tags carry a "v"; the bundle's version string does not.
    @Test func acceptsATagPrefix() throws {
        #expect(try v("v0.1.0") == v("0.1.0"))
    }

    /// A missing component is zero, not "older".
    @Test func treatsMissingComponentsAsZero() throws {
        #expect(try v("1.2") == v("1.2.0"))
        #expect(try v("1") == v("1.0.0"))
        #expect(try v("1.2") < v("1.2.1"))
    }

    @Test func stopsAtNonNumericSuffixes() throws {
        #expect(try v("1.2.0-beta.1") == v("1.2.0"))
    }

    @Test func rejectsNonsense() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("latest") == nil)
        #expect(SemanticVersion("v") == nil)
    }
}
