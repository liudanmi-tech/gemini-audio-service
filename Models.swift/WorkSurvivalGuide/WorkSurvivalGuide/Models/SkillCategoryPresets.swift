//
//  SkillCategoryPresets.swift
//  WorkSurvivalGuide
//
//  Onboarding 用的技能分类静态数据（6 类，每类 5-8 个子技能）
//

import Foundation

// MARK: - User Identity

enum UserIdentity: String, CaseIterable, Identifiable {
    case student = "student"
    case working = "working"
    case both    = "both"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .student: return "🎓"
        case .working: return "💼"
        case .both:    return "⚡"
        }
    }

    var title: String {
        switch self {
        case .student: return "I'm a Student"
        case .working: return "I'm Working"
        case .both:    return "Both / Other"
        }
    }

    var subtitle: String {
        switch self {
        case .student: return "College student or recent grad"
        case .working: return "Full-time or part-time employed"
        case .both:    return "Juggling work and school, or other"
        }
    }
}

// MARK: - Data Models

struct SkillCategory: Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let description: String
    let subSkills: [SubSkillItem]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SkillCategory, rhs: SkillCategory) -> Bool { lhs.id == rhs.id }
}

struct SubSkillItem: Identifiable, Hashable {
    let id: String
    let categoryId: String
    let name: String
    let description: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SubSkillItem, rhs: SubSkillItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Static Presets

struct SkillCategoryPresets {

    static let all: [SkillCategory] = [
        workLife, campusLife, relationships, family, personalGrowth, lifeSkills
    ]

    // ── 🏢 Work Life ──
    static let workLife = SkillCategory(
        id: "work_life", emoji: "🏢",
        name: "Work Life",
        description: "Workplace communication & career",
        subSkills: [
            sub("salary_negotiation",   "work_life", "Salary Negotiation",          "Ask for raises and negotiate offers"),
            sub("difficult_boss",       "work_life", "Difficult Boss",               "Handle micromanagement and toxic leadership"),
            sub("work_boundaries",      "work_life", "Setting Boundaries at Work",   "Say no to extra tasks without guilt"),
            sub("performance_reviews",  "work_life", "Performance Reviews",          "Advocate for yourself at review time"),
            sub("feedback",             "work_life", "Giving & Receiving Feedback",  "Handle criticism and give hard feedback"),
            sub("job_interviews",       "work_life", "Job Interviews",               "STAR method and interview prep"),
            sub("coworker_conflicts",   "work_life", "Coworker Conflicts",           "Resolve tension with teammates"),
            sub("remote_work",          "work_life", "Remote Work Communication",    "Async communication and staying visible"),
        ]
    )

    // ── 🎓 Campus Life ──
    static let campusLife = SkillCategory(
        id: "campus_life", emoji: "🎓",
        name: "Campus Life",
        description: "Student life and early career",
        subSkills: [
            sub("roommate_conflicts",    "campus_life", "Roommate Conflicts",             "Navigate shared living disagreements"),
            sub("professor_email",       "campus_life", "Talking to Professors",          "Request recommendations and research spots"),
            sub("group_projects",        "campus_life", "Group Project Tension",          "Deal with teammates who don't pull their weight"),
            sub("making_friends",        "campus_life", "Making Friends",                 "Break the ice and build real connections"),
            sub("asking_extensions",     "campus_life", "Asking for Extensions",          "Talk to professors about deadlines"),
            sub("academic_burnout",      "campus_life", "Academic Burnout",               "Recognize and recover from overload"),
            sub("internship_interview",  "campus_life", "First Internship Interview",     "Land your first internship"),
            sub("networking",            "campus_life", "Networking Without Feeling Fake","Build connections authentically"),
        ]
    )

    // ── 💕 Relationships & Dating ──
    static let relationships = SkillCategory(
        id: "relationships", emoji: "💕",
        name: "Relationships & Dating",
        description: "Romance, dating, and friendships",
        subSkills: [
            sub("partner_communication", "relationships", "Partner Communication",  "Resolve conflicts with your partner"),
            sub("talking_stage",         "relationships", "The Talking Stage",      "Navigate the early dating phase"),
            sub("ghosting_rejection",    "relationships", "Ghosting & Rejection",   "Handle being ghosted or rejecting gracefully"),
            sub("situationship",         "relationships", "Situationship Exit",     "Define or end an undefined relationship"),
            sub("dtr_conversation",      "relationships", "DTR Conversation",       "Define the relationship talk"),
            sub("breakups",              "relationships", "Breakups",               "End things clearly and kindly"),
            sub("friendship_conflicts",  "relationships", "Friendship Conflicts",   "Repair or end friendships with care"),
            sub("coming_out",            "relationships", "Coming Out",             "Share your identity with others"),
        ]
    )

    // ── 👨‍👩‍👧 Family ──
    static let family = SkillCategory(
        id: "family", emoji: "👨‍👩‍👧",
        name: "Family",
        description: "Family dynamics and boundaries",
        subSkills: [
            sub("parent_boundaries",  "family", "Boundaries with Parents",         "Push back on overinvolvement"),
            sub("immigrant_family",   "family", "Immigrant Family Communication",  "Bridge cultural gaps with your parents"),
            sub("family_money",       "family", "Money Talks with Family",         "Discuss finances without tension"),
            sub("coparenting",        "family", "Co-Parenting After Divorce",      "Communicate after separation"),
            sub("parent_teen",        "family", "Parent-Teen Communication",       "Bridge the generation gap"),
            sub("coming_out_family",  "family", "Coming Out to Family",            "Share your truth with family members"),
        ]
    )

    // ── 🌱 Personal Growth ──
    static let personalGrowth = SkillCategory(
        id: "personal_growth", emoji: "🌱",
        name: "Personal Growth",
        description: "Mental health and self-development",
        subSkills: [
            sub("assertiveness",     "personal_growth", "Assertiveness & Self-Advocacy", "Express needs directly and confidently"),
            sub("imposter_syndrome", "personal_growth", "Imposter Syndrome",             "Overcome feeling like you don't belong"),
            sub("social_anxiety",    "personal_growth", "Social Anxiety",                "Navigate social situations with less fear"),
            sub("burnout_recovery",  "personal_growth", "Burnout Recovery",              "Rebuild energy after hitting a wall"),
            sub("anger_management",  "personal_growth", "Anger Management",              "Respond instead of react"),
            sub("friend_crisis",     "personal_growth", "Helping a Friend in Crisis",    "Support someone who's struggling"),
            sub("dealing_criticism", "personal_growth", "Dealing with Criticism",        "Receive hard feedback without shutting down"),
            sub("boundary_setting",  "personal_growth", "Boundary Setting",              "Protect your time and energy"),
        ]
    )

    // ── 🏠 Life Skills ──
    static let lifeSkills = SkillCategory(
        id: "life_skills", emoji: "🏠",
        name: "Life Skills",
        description: "Everyday adulting challenges",
        subSkills: [
            sub("healthcare_advocacy",  "life_skills", "Healthcare Advocacy",         "Communicate with doctors and insurers"),
            sub("customer_service",     "life_skills", "Difficult Customer Service",  "Get refunds and resolve complaints"),
            sub("money_conversations",  "life_skills", "Money Conversations",         "Talk about splitting bills and lending"),
            sub("neighbor_conflicts",   "life_skills", "Neighbor & Community",        "Handle noise, parking, and disputes"),
            sub("landlord_comm",        "life_skills", "Landlord Communication",      "Negotiate repairs, deposits, and rent"),
        ]
    )

    // MARK: - Helpers

    static func categories(for identity: UserIdentity) -> [SkillCategory] {
        switch identity {
        case .student: return [campusLife, relationships, personalGrowth, family, workLife, lifeSkills]
        case .working: return [workLife, personalGrowth, relationships, lifeSkills, family, campusLife]
        case .both:    return all
        }
    }

    private static func sub(_ id: String, _ cat: String, _ name: String, _ desc: String) -> SubSkillItem {
        SubSkillItem(id: id, categoryId: cat, name: name, description: desc)
    }
}
