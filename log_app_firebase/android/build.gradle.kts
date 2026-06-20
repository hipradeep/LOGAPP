allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Define the 'flutter' property mapping to resolve build failures in plugins like ':jni'
    // that attempt to read 'flutter.ndkVersion' from project properties
    extra.set("flutter", mapOf(
        "ndkVersion" to "27.0.12077973"
    ))
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
