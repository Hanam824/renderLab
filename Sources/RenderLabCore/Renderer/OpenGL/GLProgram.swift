import OpenGL.GL3

/// Compiles and links a vertex + fragment shader into a GL program object.
/// Needs a current OpenGL context on the calling thread.
struct GLProgram {
    enum BuildError: Error, CustomStringConvertible {
        case compile(stage: String, log: String)
        case link(log: String)

        var description: String {
            switch self {
            case .compile(let stage, let log): return "\(stage) shader failed to compile:\n\(log)"
            case .link(let log): return "program failed to link:\n\(log)"
            }
        }
    }

    let id: GLuint

    init(vertexSource: String, fragmentSource: String) throws {
        let vertex = try Self.compile(GLenum(GL_VERTEX_SHADER), vertexSource, stage: "vertex")
        defer { glDeleteShader(vertex) }
        let fragment = try Self.compile(GLenum(GL_FRAGMENT_SHADER), fragmentSource, stage: "fragment")
        defer { glDeleteShader(fragment) }

        let program = glCreateProgram()
        glAttachShader(program, vertex)
        glAttachShader(program, fragment)
        glLinkProgram(program)

        var status: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        guard status == GL_TRUE else {
            let log = Self.infoLog(program, getLength: glGetProgramiv, getLog: glGetProgramInfoLog)
            glDeleteProgram(program)
            throw BuildError.link(log: log)
        }
        id = program
    }

    /// Loads `Shaders/opengl/<name>.vert|frag` from the bundle.
    init(named name: String) throws {
        try self.init(
            vertexSource: ShaderLibrary.source(name, .vertex),
            fragmentSource: ShaderLibrary.source(name, .fragment)
        )
    }

    func delete() {
        glDeleteProgram(id)
    }

    private static func compile(_ type: GLenum, _ source: String, stage: String) throws -> GLuint {
        let shader = glCreateShader(type)
        source.withCString { cString in
            var pointer: UnsafePointer<GLchar>? = cString
            glShaderSource(shader, 1, &pointer, nil)
        }
        glCompileShader(shader)

        var status: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        guard status == GL_TRUE else {
            let log = infoLog(shader, getLength: glGetShaderiv, getLog: glGetShaderInfoLog)
            glDeleteShader(shader)
            throw BuildError.compile(stage: stage, log: log)
        }
        return shader
    }

    private static func infoLog(
        _ object: GLuint,
        getLength: (GLuint, GLenum, UnsafeMutablePointer<GLint>?) -> Void,
        getLog: (GLuint, GLsizei, UnsafeMutablePointer<GLsizei>?, UnsafeMutablePointer<GLchar>?) -> Void
    ) -> String {
        var length: GLint = 0
        getLength(object, GLenum(GL_INFO_LOG_LENGTH), &length)
        guard length > 0 else { return "(no log)" }
        var buffer = [GLchar](repeating: 0, count: Int(length))
        getLog(object, length, nil, &buffer)
        return String(cString: buffer)
    }
}

/// Reads a string from `glGetString`, e.g. `glString(GL_VERSION)`.
func glString(_ name: Int32) -> String {
    guard let pointer = glGetString(GLenum(name)) else { return "?" }
    return String(cString: pointer)
}
