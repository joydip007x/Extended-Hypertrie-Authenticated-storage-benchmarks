#[cfg(not(target_os = "windows"))]
use pprof::{protos::Message, ProfilerGuard, Report};
#[cfg(not(target_os = "windows"))]
use std::fs::File;
#[cfg(not(target_os = "windows"))]
use std::io::Write;

#[cfg(not(target_os = "windows"))]
pub struct Profiler {
    inner: Option<ProfilerGuard<'static>>,
    frequency: i32,
    reports: Vec<Report>,
}

#[cfg(not(target_os = "windows"))]
impl Profiler {
    pub fn new(frequency: i32) -> Self {
        if frequency > 0 {
            Self {
                inner: Some(pprof::ProfilerGuard::new(frequency).unwrap()),
                frequency,
                reports: Vec::new(),
            }
        } else {
            Self {
                inner: None,
                frequency,
                reports: Vec::new(),
            }
        }
    }

    pub fn tick(&mut self) {
        if self.frequency <= 0 {
            return;
        }
        let profiler = std::mem::take(&mut self.inner).unwrap();
        let report = profiler.report().build().unwrap();
        self.reports.push(report);
        std::mem::drop(profiler);
        self.inner = Some(pprof::ProfilerGuard::new(self.frequency).unwrap())
    }

    pub fn report_to_file(self, prefix: &str) {
        if self.frequency <= 0 {
            return;
        }
        print!("Writing profiles... ");

        for (index, report) in self.reports.into_iter().enumerate() {
            let path = format!("{}_{:02}.pb", prefix, index);
            let mut file = File::create(path).unwrap();
            let profile = report.pprof().unwrap();

            let mut content = Vec::new();
            profile.encode(&mut content).unwrap();
            file.write_all(&content).unwrap();
        }
        println!("Done");
    }
}

// Windows stub: pprof is not supported on Windows; profiling is a no-op.
#[cfg(target_os = "windows")]
pub struct Profiler;

#[cfg(target_os = "windows")]
impl Profiler {
    pub fn new(_frequency: i32) -> Self { Profiler }
    pub fn tick(&mut self) {}
    pub fn report_to_file(self, _prefix: &str) {}
}
