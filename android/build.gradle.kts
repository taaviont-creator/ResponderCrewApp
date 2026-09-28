plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

gradle.taskGraph.whenReady {
    if (System.getProperty("os.name").startsWith("Windows") && newBuildDir.asFile.exists()) {
        rootProject.exec {
            commandLine("attrib.exe", "-R", newBuildDir.asFile.absolutePath, "/D")
        }
        rootProject.exec {
            commandLine("attrib.exe", "-R", "${newBuildDir.asFile.absolutePath}\\*", "/S", "/D")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
