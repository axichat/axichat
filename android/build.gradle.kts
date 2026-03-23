import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        tasks.configureEach {
            if (name.contains("LintModel") || name.startsWith("lint")) {
                enabled = false
            }
        }

        if (name != "flutter_inappwebview_android") {
            return@afterEvaluate
        }

        extensions.findByType(LibraryExtension::class.java)?.buildTypes?.getByName("release")?.apply {
            isMinifyEnabled = false
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
