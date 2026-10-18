import OpenGL
import OpenGL.GL3
import Testing
@testable import RenderLabCore

/// A windowless OpenGL 4.1 Core context made with CGL, the C API under NSOpenGLContext.
final class HeadlessGLContext {
    let context: CGLContextObj

    init?() {
        let attributes: [CGLPixelFormatAttribute] = [
            kCGLPFAOpenGLProfile, CGLPixelFormatAttribute(UInt32(kCGLOGLPVersion_GL4_Core.rawValue)),
            kCGLPFAAccelerated,
            CGLPixelFormatAttribute(0),
        ]
        var pixelFormat: CGLPixelFormatObj?
        var count: GLint = 0
        guard CGLChoosePixelFormat(attributes, &pixelFormat, &count) == kCGLNoError, let pixelFormat else { return nil }
        defer { CGLDestroyPixelFormat(pixelFormat) }

        var context: CGLContextObj?
        guard CGLCreateContext(pixelFormat, nil, &context) == kCGLNoError, let context else { return nil }
        self.context = context
        CGLSetCurrentContext(context)
    }

    deinit {
        CGLSetCurrentContext(nil)
        CGLDestroyContext(context)
    }

    static var isAvailable: Bool { HeadlessGLContext() != nil }
}

@Suite(.tags(.gpu), .serialized, .enabled(if: HeadlessGLContext.isAvailable, "no OpenGL 4.1 context available"))
struct OpenGLContextTests {
    @Test func contextIsOpenGL41Core() throws {
        let gl = try #require(HeadlessGLContext())
        withExtendedLifetime(gl) {
            #expect(glString(GL_VERSION).hasPrefix("4.1"))
            #expect(glString(GL_SHADING_LANGUAGE_VERSION).hasPrefix("4.10"))
        }
    }

    @Test func triangleShadersCompileAndLink() throws {
        let gl = try #require(HeadlessGLContext())
        try withExtendedLifetime(gl) {
            let program = try GLProgram(named: "triangle")
            #expect(program.id != 0)
            program.delete()
        }
    }

    @Test func compileErrorIncludesLog() throws {
        let gl = try #require(HeadlessGLContext())
        withExtendedLifetime(gl) {
            #expect {
                _ = try GLProgram(vertexSource: "#version 410 core\nvoid main() { oops }", fragmentSource: "")
            } throws: { error in
                guard case GLProgram.BuildError.compile(let stage, let log) = error else { return false }
                return stage == "vertex" && !log.isEmpty
            }
        }
    }
}
